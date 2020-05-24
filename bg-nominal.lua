local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular case/number/definiteness (and gender for adjectives) combination.
	 Example slot names for nouns are "ind_pl" (indefinite plural), "def_obj_sg" (definite objective
	 singular), "voc_sg" (vocative singular). Example slot names for adjectives are "ind_pl"
	 (indefinite plural) and "def_obj_m_sg" (definite object masculine singular) Each slot is filled
	 with zero or more forms.

-- "form" = The declined Bulgarian form representing the value of a given slot. For example, мо́мко
	 is a form, representing the value of the voc_sg slot of the lemma мо́мък "youth".

-- "lemma" = The dictionary form of a given Bulgarian term. Generally the indefinite (masculine)
	 singular, but will be the indefinite plural of plurale tantum nouns (e.g. га́щи "pants"), and
	 may occasionally be another form if the indefinite (masculine) singular is missing.

-- "plurale tantum" (plural "pluralia tantum") = A noun that exists only in the plural. Examples are
	 очила́ "glasses" and три́ци "bran".

-- "singulare tantum" (plural "singularia tantum") = A noun that exists only in the singular.
	Examples are ори́з "rice" and Бълга́рия "Bulgaria".
]=]

local lang = require("Module:languages").getByCode("bg")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:bg-common")

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


local noun_overriding_forms = {
	["pl"] = true,
	["ind"] = true,
	["def"] = true,
	["def_sub"] = true,
	["def_obj"] = true,
	["count"] = true,
	["voc"] = true,
	["acc"] = true,
	["gen"] = true,
	["dat"] = true,
	["ind_pl"] = true,
	["def_pl"] = true,
	["voc_pl"] = true,
	["acc_pl"] = true,
	["gen_pl"] = true,
	["dat_pl"] = true,
}


local boolean_noun_overriding_props = {
	["-pl"] = true,
	["-def"] = true,
	["-def_pl"] = true,
	["-count"] = true,
}


local boolean_adj_overriding_props = {
	["dva"] = true,
	["koj"] = true,
	["chij"] = true,
	["-voc"] = true,
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

local extra_noun_cases = {"acc", "gen", "dat"}

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
	-- Extra slot for possessive forms.
	["short"] = "short|form",
	-- Extra slots for два and related words.
	["ind_m_pl"] = "indef|m|p",
	["def_m_pl"] = "def|m|p",
	["ind_fn_pl"] = "indef|f|p|;|indef|n|p",
	["def_fn_pl"] = "def|f|p|;|def|n|p",
	-- Extra slot for demonstrative and interrogative pronouns.
	["m_sg"] = "m|s",
	["nom_m_sg"] = "nom|m|s",
	["acc_m_sg"] = "acc|m|s",
	["dat_m_sg"] = "dat|m|s",
	["f_sg"] = "f|s",
	["n_sg"] = "n|s",
	["pl"] = "p",
}

local masc_adj_to_noun_slots = {
	["ind_m_sg"] = {"ind_sg", "acc_sg", "gen_sg", "dat_sg"},
	["def_sub_m_sg"] = "def_sub_sg",
	["def_obj_m_sg"] = "def_obj_sg",
	["voc_m_sg"] = "voc_sg",
}

local fem_adj_to_noun_slots = {
	["ind_f_sg"] = {"ind_sg", "voc_sg", "acc_sg", "gen_sg", "dat_sg"},
	["def_f_sg"] = {"def_sub_sg", "def_obj_sg"},
}

local neut_adj_to_noun_slots = {
	["ind_n_sg"] = {"ind_sg", "voc_sg", "acc_sg", "gen_sg", "dat_sg"},
	["def_n_sg"] = {"def_sub_sg", "def_obj_sg"},
}

local pl_adj_to_noun_slots = {
	["ind_pl"] = {"ind_pl", "count", "voc_pl", "acc_pl", "gen_pl", "dat_pl"},
	["def_pl"] = "def_pl",
}

local potential_noun_lemma_slots = {
	"ind_sg",
	"ind_pl"
}

local potential_adj_lemma_slots = {
	"ind_m_sg",
	"ind_pl"
}


-- Add a tracking category to the page.
local function track(page)
	require("Module:debug").track("bg-nominal/" .. page)
	return true
end


-- Given an alternating run of the format returned by `parse_balanced_segment_run`,
-- where the even-numbered segments are footnotes and the whole run describes an adjective
-- accent spec (e.g. "b*(я)" split as {"b*(я)"}), parse the accent spec and return an object
-- describing this spec. No footnotes are currently allowed in the accent spec and hence an
-- error will be thrown if there are any even-numbered segments. The returned object is e.g.
-- (for the above spec)
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
-- nocomp = BOOLEAN
-- ch = BOOLEAN
-- che = BOOLEAN
-- ur = BOOLEAN
local function parse_adj_accent_spec(accent_run)
	if #accent_run ~= 1 then
		error("Bracketed footnotes not allowed in adjective accent specs: '" .. table.concat(accent_run) .. "'")
	end
	local retval = {accents = {}}
	local accents, rest = accent_run[1]:match("^([ab]*)(.-)$")
	for accent in accents:gmatch(".") do
		table.insert(retval.accents, accent)
	end
	rest, retval.reducible = rsubb(rest, "%*", "")
	rest, retval.nocomp = rsubb(rest, "!", "")
	rest, retval.soft_sign = rsubb(rest, "%(ь%)", "")
	rest, retval.ch = rsubb(rest, "%(ч%)", "")
	rest, retval.che = rsubb(rest, "%(че%)", "")
	rest, retval.ur = rsubb(rest, "%(ър%)", "")
	rest, retval.ya = rsubb(rest, "%(я%)", "")
	if rest ~= "" then
		error("Unrecognized indicator: '" .. rest .. "'")
	end
	return retval
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
-- human = BOOLEAN
-- soft_sign = BOOLEAN
-- no_sign_sign = BOOLEAN
-- remove_in = BOOLEAN
-- ur = BOOLEAN
local function parse_noun_accent_spec(accent_run)
	local retval = {accents = {}, plurals = {}}
	local plurals = {}
	local plural_groups = iut.split_alternating_runs(accent_run, "%+")
	local double_plus = false
	for i, plural_group in ipairs(plural_groups) do
		if i > 1 and retval.is_adj then
			error("Explicit plurals not allowed with adjectival forms: '" .. table.concat(accent_run) .. "'")
		elseif i > 1 then
			if #plural_group == 1 and plural_group[1] == "" then
				if double_plus then
					error("Too many plus signs: '" .. table.concat(accent_run) .. "'")
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
			error("Bracketed footnotes not allowed in accent specs: '" .. table.concat(plural_group) .. "'")
		else
			local rest
			rest, retval.is_adj = rsubb(plural_group[1], "#", "")
			if retval.is_adj then
				retval.nocomp = true
				rest, retval.has_vocative = rsubb(rest, "%(v%)", "")
				rest, retval.human = rsubb(rest, "%(h%)", "")
				local adj_accent_spec = parse_adj_accent_spec({rest})
				for prop, value in pairs(adj_accent_spec) do
					retval[prop] = value
				end
			else
				local accents
				local accents, rest = plural_group[1]:match("^([abcd]*)(.-)$")
				for accent in accents:gmatch(".") do
					table.insert(retval.accents, accent)
				end
				rest, retval.reducible_vocative = rsubb(rest, "%(v%*%)", "")
				rest, retval.reducible_count = rsubb(rest, "%(c%*%)", "")
				rest, retval.reducible_definite = rsubb(rest, "%(d%*%)", "")
				rest, retval.reducible = rsubb(rest, "%*", "")
				rest, retval.has_vocative = rsubb(rest, "%(v%)", "")
				rest, retval.human = rsubb(rest, "%(h%)", "")
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
-- "sg", "pl" or "both", and if the form name is in `negative_*_overriding_forms`, the second value
-- will be `true`. Only the following form names are allowed:
--   * if from_noun, "n"
--   * if not is_adj, the keys in `noun_overriding_forms` and `boolean_noun_overriding_props`
--   * if is_adj and not from_noun, the keys in `boolean_adj_overriding_props`
--   * if is_adj and not from_noun, the keys in `adj_slots`
--   * if is_adj and from_noun, the keys in `noun_slots`
-- Note than `from_noun` should be true if the overall declension is of a noun
-- (including adjectival nouns) and `is_adj` should be true if the particular term we're
-- declining is an adjective or adjectival noun.
local function parse_form_spec(form_run, from_noun, is_adj)
	local colon_separated_groups = iut.split_alternating_runs(form_run, ":")
	local form_name_group = colon_separated_groups[1]
	if #form_name_group ~= 1 then
		error("Bracketed footnotes not allowed after form name: '" .. table.concat(form_name_group) .. "'")
	end
	local form_name = form_name_group[1]
	if from_noun and form_name == "n" then
		if #colon_separated_groups == 2 and #colon_separated_groups[2] == 1 then
			local number = colon_separated_groups[2][1]
			if number == "sg" or number == "pl" or number == "both" then
				return "n", number
			end
		end
		error("Number spec should be 'n:sg', 'n:pl' or 'n:both': '" .. table.concat(form_run))
	elseif (
		not is_adj and boolean_noun_overriding_props[form_name] or
		is_adj and not from_noun and boolean_adj_overriding_props[form_name]
	) then
		if #colon_separated_groups > 1 then
			error("Cannot specify a value for boolean spec '" .. form_name .. "'")
		end
		return form_name, true
	elseif (
		not is_adj and noun_overriding_forms[form_name] or
		is_adj and not from_noun and adj_slots[form_name] or
		is_adj and from_noun and noun_slots[form_name]
	) then
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


-- Given an angle-bracket spec (the entire spec following a lemma, including the angle brackets),
-- parse the noun accent and form specs inside the angle brackets. The return value is a list of
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
local function parse_noun_accent_and_form_specs(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local bracketed_runs = iut.parse_balanced_segment_run(inside, "[", "]")
	local comma_separated_groups = iut.split_alternating_runs(bracketed_runs, ",")
	local accent_and_form_specs = {}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		local accent_and_form_spec = {}
		local slash_separated_groups = iut.split_alternating_runs(comma_separated_group, "/")
		accent_and_form_spec.accent_spec = parse_noun_accent_spec(slash_separated_groups[1])
		for i, slash_separated_group in ipairs(slash_separated_groups) do
			if i > 1 then
				local form_name, forms = parse_form_spec(slash_separated_group,
					"from noun", accent_and_form_spec.accent_spec.is_adj)
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


-- Given an angle-bracket spec (the entire spec following a lemma, including the angle brackets),
-- parse the adjective accent and form specs inside the angle brackets. The return value is a list of
-- accent-and-form specs, where each such spec is an object with a field 'accent_spec' in the
-- format returned by parse_noun_accent_spec(). Currently there are no other fields describing forms;
-- that may change.
--
-- For example, given "<a*,b/def_f_sg:мо́ята:мо́йта[p]>", the return value will be
-- 
-- {
--   {
--     accent_spec = {
--       accents = {"a"},
--       reducible = true,
--     }
--   },
--   {
--     accent_spec = {
--       accents = {"b"},
--     },
--     def_f_sg = {{value = "мо́ята"}, {value = "мо́йта", footnotes = {"[p]"}}},
--   },
-- }
local function parse_adj_accent_and_form_specs(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local bracketed_runs = iut.parse_balanced_segment_run(inside, "[", "]")
	local comma_separated_groups = iut.split_alternating_runs(bracketed_runs, ",")
	local accent_and_form_specs = {}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		local accent_and_form_spec = {}
		local slash_separated_groups = iut.split_alternating_runs(comma_separated_group, "/")
		accent_and_form_spec.accent_spec = parse_adj_accent_spec(slash_separated_groups[1])
		for i, slash_separated_group in ipairs(slash_separated_groups) do
			if i > 1 then
				local form_name, forms = parse_form_spec(slash_separated_group, false, "is adj")
				if accent_and_form_spec[form_name] then
					error("Cannot specify '" .. form_name .. "' twice")
				end
				accent_and_form_spec[form_name] = forms
			end
		end
		table.insert(accent_and_form_specs, accent_and_form_spec)
	end
	return accent_and_form_specs
end


-- Parse a multiword spec such as "[[слънчев|слъ́нчева]]<#> [[систе́ма]]<>".
-- The return value is a table of the form
-- {
--   word_specs = {WORD_SPEC, WORD_SPEC, ...},
--   post_text = "TEXT-AT-END",
-- }
--
-- where WORD_SPEC describes an individual declined word and "TEXT-AT-END" is any raw text that
-- may occur after all declined words. Each WORD_SPEC is of the form
--
-- {
--   lemma = "LEMMA",
--   accent_and_form_specs = {ACCENT_AND_FORM_SPEC, ACCENT_AND_FORM_SPEC, ...}
--   before_text = "TEXT-BEFORE-WORD",
--   forms = {},
-- }
--
-- For example, the return value for "[[слънчев|слъ́нчева]]<#> [[систе́ма]]<>" is
-- {
--   word_specs = {
--     {
--       lemma = "[[слънчев|слъ́нчева]]",
--       accent_and_form_specs = {
--         {
--           accent_spec = {
--             is_adj = true,
--           }
--         },
--       }
--       before_text = "",
--       forms = {},
--     },
--     {
--       lemma = "[[систе́ма]]",
--       accent_and_form_specs = {
--         {
--           accent_spec = {
--           }
--         },
--       }
--       before_text = " ",
--       forms = {},
--     },
--   },
--   post_text = "",
-- }
local function parse_multiword_spec(segments, is_adj)
	local multiword_spec = {
		word_specs = {}
	}
	for i = 2, #segments - 1, 2 do
		local word_spec = {}
		local bracketed_runs = iut.parse_balanced_segment_run(segments[i - 1], "[", "]")
		local space_separated_groups = iut.split_alternating_runs(bracketed_runs, "[ %-]", "preserve splitchar")
		local before_text = {}
		for j, space_separated_group in ipairs(space_separated_groups) do
			if j == #space_separated_groups then
				word_spec.lemma = m_links.remove_links(table.concat(space_separated_group))
				if word_spec.lemma == "" then
					error("Word is blank: '" .. table.concat(segments) .. "'")
				end
			else
				table.insert(before_text, table.concat(space_separated_group))
			end
		end
		word_spec.before_text = m_links.remove_links(table.concat(before_text))
		word_spec.accent_and_form_specs = is_adj and parse_adj_accent_and_form_specs(segments[i]) or
			parse_noun_accent_and_form_specs(segments[i])
		word_spec.forms = {}
		table.insert(multiword_spec.word_specs, word_spec)
	end
	multiword_spec.post_text = m_links.remove_links(segments[#segments])
	return multiword_spec
end


-- Parse an alternant, e.g. "((мо́лив<>,моли́в<>))". The return value is a table of the form
-- {
--   alternants = {MULTIWORD_SPEC, MULTIWORD_SPEC, ...}
-- }
--
-- where MULTIWORD_SPEC describes a given alternant and is as returned by parse_multiword_spec().
local function parse_alternant(alternant, is_adj)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = iut.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(segments, ",")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants, parse_multiword_spec(comma_separated_group, is_adj))
end
	return alternant_spec
end


-- Top-level parsing function. Parse a multiword spec that may have alternants in it.
-- The return value is a table of the form
-- {
--   alternant_or_word_specs = {ALTERNANT_OR_WORD_SPEC, ALTERNANT_OR_WORD_SPEC, ...}
--   post_text = "TEXT-AT-END",
-- }
--
-- where ALTERNANT_OR_WORD_SPEC is either an alternant spec as returned by parse_alternant()
-- or a word spec as described in the comment above parse_multiword_spec(). An alternant spec
-- looks as follows:
-- {
--   alternants = {MULTIWORD_SPEC, MULTIWORD_SPEC, ...},
--   before_text = "TEXT-BEFORE-ALTERNANT",
-- }
-- i.e. it is like what is returned by parse_alternant() but has an extra `before_text` field.
local function parse_alternant_multiword_spec(text, is_adj)
	local alternant_multiword_spec = {alternant_or_word_specs = {}}
	local alternant_segments = m_string_utilities.capturing_split(text, "(%(%(.-%)%))")
	local last_post_text
	for i = 1, #alternant_segments do
		if i % 2 == 1 then
			local segments = iut.parse_balanced_segment_run(alternant_segments[i], "<", ">")
			local multiword_spec = parse_multiword_spec(segments, is_adj)
			for _, word_spec in ipairs(multiword_spec.word_specs) do
				table.insert(alternant_multiword_spec.alternant_or_word_specs, word_spec)
			end
			last_post_text = multiword_spec.post_text
		else
			local alternant_spec = parse_alternant(alternant_segments[i], is_adj)
			alternant_spec.before_text = last_post_text
			table.insert(alternant_multiword_spec.alternant_or_word_specs, alternant_spec)
		end
	end
	alternant_multiword_spec.post_text = last_post_text
	return alternant_multiword_spec
end


local function map_word_specs(alternant_multiword_spec, fun)
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					fun(word_spec)
				end
			end
		else
			fun(alternant_or_word_spec)
		end
	end
end


-- Check that multisyllabic lemmas have stress, and add stress to monosyllabic
-- lemmas if needed.
local function check_lemma_stress(alternant_multiword_spec)
	map_word_specs(alternant_multiword_spec, function(word_spec)
		word_spec.lemma = com.add_monosyllabic_stress(word_spec.lemma)
		if not rfind(word_spec.lemma, AC) then
			error("Multisyllabic lemma '" .. word_spec.lemma .. "' needs an accent")
		end
	end)
end


-- Construct the "reduced" version of a stem. This removes an е or ъ followed by a word-final
-- consonant, stresses the final syllable of the result if necessary, and converts бое́ц into бо́йц- and бо́як into бо́йк-.
-- An error is thrown if the stem can't be reduced.
local function reduce_stem(stem)
	local vowel_ending_stem, final_cons = rmatch(stem, "^(.*" .. com.vowel_c .. AC .. "?)[ея]́?(" .. com.cons_c .. ")$")
	if vowel_ending_stem then
		-- бое́ц etc.
		return com.maybe_stress_final_syllable(vowel_ending_stem .. "й" .. final_cons)
	end
	local initial_stem, final_cons = rmatch(stem, "^(.*)[еъ]́?(" .. com.cons_c .. ")$")
	if initial_stem then
		return com.maybe_stress_final_syllable(initial_stem .. final_cons)
	end
	error("Unable to reduce stem: '" .. stem .. "'")
end


-- Return the stem of a given noun. This removes any endings -а/-я/-е/-о/-й, and if
-- the result lacks an accent, it is added onto the last syllable.
local function get_noun_stem(lemma)
	local stem
	stem = rmatch(lemma, "^(.*)[аеоя]́?$")
	if stem then
		return com.maybe_stress_final_syllable(stem)
	end
	stem = rmatch(lemma, "^(%u.*)и́?$")
	if stem then
		-- proper names like До́бри
		return com.maybe_stress_final_syllable(stem)
	end
	stem = rmatch(lemma, "^(.*)й$")
	if stem then
		return stem
	end
	return lemma
end


-- Return the stem of a given adjective. This does the following:
-- (1) removes an ending -и, and if the result lacks an accent, it is added onto the last syllable;
-- (2) if (ър) was given, converts -ъ́р- to -ръ́- and vice-versa;
-- (3) if (я) was given, converts -е́- to -я́-;
-- (4) reduces the stem if appropriate.
local function get_adj_stem(lemma, accent_and_form_spec, as_noun)
	local accent_spec = accent_and_form_spec.accent_spec
	if as_noun and (accent_and_form_spec.n == "pl" or accent_spec.gender ~= "m") then
		-- If we're dealing with a feminine singular, neuter singular or plural adjectival noun form,
		-- we need to remove the ending to get the stem. No need to do any further frobbing, as the
		-- resulting stem will be used for all forms.
		local stem = rsub(lemma, "[аяеои]́?$", "")
		return com.maybe_stress_final_syllable(stem)
	end
	local stem = rmatch(lemma, "^(.*)и́?$")
	if stem then
		stem = com.maybe_stress_final_syllable(stem)
	else
		stem = rmatch(lemma, "^(.*)й$") or lemma
	end
	if accent_spec.ur then
		if rfind(stem, "ъ́р") then
			stem = rsub(stem, "ъ́р", "ръ́")
		elseif rfind(stem, "ръ́") then
			stem = rsub(stem, "ръ́", "ъ́р")
		else
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


-- Construct all the stems needed for declining an adjective. This does the following:
-- (1) adds stress to a monosyllabic lemma if needed;
-- (2) throws an error if a multisyllabic lemma is given without any stress;
-- (3) constructs the stem of each accent_spec using get_adj_stem().
local function construct_adj_stems(alternant_multiword_spec)
	map_word_specs(alternant_multiword_spec, function(word_spec)
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			local accent_spec = accent_and_form_spec.accent_spec
			accent_spec.stem = get_adj_stem(word_spec.lemma, accent_and_form_spec)
		end
	end)
end


-- Construct all the stems needed for declining a noun. This does the following:
-- (1) constructs the stem using get_noun_stem();
-- (2) constructs the reduced stem using reduce_stem(), if needed.
-- We don't construct the reduced stem unless the user gave a reduction spec somewhere;
-- otherwise we'll get an error on non-reducible stems.
local function construct_noun_stems(alternant_multiword_spec)
	map_word_specs(alternant_multiword_spec, function(word_spec)
		word_spec.stem = get_noun_stem(word_spec.lemma)
		local needs_reduced_stem = false
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			local accent_spec = accent_and_form_spec.accent_spec
			if accent_spec.is_adj then
				accent_spec.stem = get_adj_stem(word_spec.lemma, accent_and_form_spec, "as noun")
			elseif accent_spec.reducible or accent_spec.reducible_definite or accent_spec.reducible_count or
				accent_spec.reducible_vocative then
				needs_reduced_stem = true
				break
			end
		end
		if needs_reduced_stem then
			word_spec.reduced_stem = reduce_stem(word_spec.stem)
		end
	end)
end


-- Concatenate a stem and an ending. If the ending has an accent, any accent on the stem is removed.
-- If UR is specified, convert the sequence CръC to CърC, preserving any accent on -ъ-.
local function combine_stem_and_ending(stem, ending, accent_spec, is_adj)
	if not is_adj and accent_spec.ur and rfind(ending, "^" .. com.vowel_c) then
		stem = rsub(stem, "(" .. com.cons_c .. ")ръ(" .. AC .. "?)(" .. com.cons_c .. ")", "%1ъ%2р%3")
	end
	if not accent_spec.no_ya and (rfind(ending, AC) or (accent_spec.ya and rfind(ending, "^[еиь]"))) then
		stem = rsub(stem, "я́", "е́")
	end
	if rfind(ending, AC) then
		stem = rsub(stem, AC, "")
	end
	return stem .. ending
end


-- Given an adjective and an accent-and-form spec (an element of the list returned by parse_accent_and_form_specs()),
-- do any autodetection of gender, accent and indicators. This modifies the accent-and-form spec in place.
local function detect_adj_accent_and_form_spec(lemma, accent_and_form_spec)
	local accent_spec = accent_and_form_spec.accent_spec
	-- Detect accent if not specified.
	if #accent_spec.accents == 0 then
		local accent
		if rfind(lemma, "и́$") then
			accent = "b"
		elseif accent_spec.reducible and rfind(lemma, "[ъяе]́" .. com.cons_c .. "$") then
			-- Reducible adjective and accent on reducible vowel, e.g. добъ́р -> fem добра́
			accent = "b"
		else
			accent = "a"
		end
		table.insert(accent_spec.accents, accent)
	end
	-- Detect soft-sign indicator.
	local accent_spec = accent_and_form_spec.accent_spec
	if rfind(lemma, "и́?$") and accent_spec.soft_sign then
		accent_spec.soft_sign_i = true
	end
	if rfind(lemma, "й$") then
		-- мой, твой, etc.
		accent_spec.soft_sign = true
		accent_spec.soft_sign_i = true
	end
end


-- Given a noun and an accent-and-form spec (an element of the list returned by parse_accent_and_form_specs()),
-- do any autodetection of gender, accent and indicators. This modifies the accent-and-form spec in place.
local function detect_noun_accent_and_form_spec(lemma, accent_and_form_spec)
	local accent_spec = accent_and_form_spec.accent_spec
	if accent_spec.is_adj then
		-- Detect gender if not specified.
		if rfind(lemma, "[ая]́?$") then
			g = "f"
		elseif rfind(lemma, "[ео]́?$") then
			g = "n"
		else
			g = "m"
		end
		accent_spec.gender = g
		-- Detect has-vocative indicator.
		if accent_spec.human or accent_and_form_spec.voc_sg or accent_and_form_spec.voc_pl then
			accent_spec.has_vocative = true
		end
		-- Detect has-count indicator.
		if accent_and_form_spec.count then
			accent_spec.has_count = true
		end
		detect_adj_accent_and_form_spec(lemma, accent_and_form_spec)
	else
		-- Detect gender if not specified.
		local g = accent_spec.gender
		if not g then
			if rfind(lemma, "[ая]́?$") then
				g = "f"
			elseif rfind(lemma, "^%u.*и́?$") then
				-- proper names like До́бри
				g = "m"
			elseif rfind(lemma, "[еиоую]́?$") then
				g = "n"
			else
				g = "m"
			end
			accent_spec.gender = g
		end
		-- Detect accent if not specified.
		if #accent_spec.accents == 0 then
			local accent
			if g == "f" and rfind(lemma, com.cons_c .. "$") then
				accent = "d"
			elseif accent_spec.reducible and rfind(lemma, "[ъе]́" .. com.cons_c .. "$") then
				-- Reducible noun and accent on reducible vowel, e.g. чуждене́ц -> чужденци́
				accent = "c"
			elseif rfind(lemma, "[еоая]́$") then
				accent = "c"
			else
				accent = "a"
			end
			table.insert(accent_spec.accents, accent)
		end
		-- Detect soft-sign indicator.
		if g == "m" and not accent_spec.no_soft_sign and (
			rfind(lemma, "й$") or rfind(lemma, com.vowel_c .. AC .. "?тел$") or rfind(lemma, com.vowel_c .. AC .. "?" .. com.cons_c .. "+а́?р$")
		) then
			accent_spec.soft_sign = true
		end
		-- Detect plural if not specified.
		if #accent_spec.plurals == 0 then
			local plural
			if g == "f" then
				plural = "и"
			elseif g == "m" then
				if rfind(lemma, "^%u") then
					if rfind(lemma, "[ияй]́?$") then
						-- До́бри, Или́я, Благо́й
						plural = "евци"
					elseif rfind(lemma, "[ое]́?в$") then
						-- Ива́нов/Ивано́в, Пе́нчев
						plural = {"и", "ци"}
					else
						-- Пе́тър, Ива́н, Кру́м, Нико́ла
						plural = "овци"
					end
				elseif rfind(lemma, "о́?$") then
					-- дя́до, гле́зльо
					plural = "овци"
				elseif rfind(lemma, "е́?$") then
					-- аташе́
					plural = "ета"
				elseif not com.is_monosyllabic(lemma) then
					-- ези́к, друга́р, геро́й, etc.; баща́, коле́га
					plural = "и"
				elseif rfind(lemma, "й$") then
					-- край, брой
					plural = "еве"
				elseif accent_spec.soft_sign then
					-- кон, зет, цар
					plural = "ьове"
				else
					plural = "ове"
				end
			elseif rfind(lemma, "о́?$") or rfind(lemma, "[щц]е́?$") then
				plural = "а"
			elseif rfind(lemma, "и́?е$") then
				plural = "я"
			elseif rfind(lemma, "ане$") then
				-- ди́шане, схва́щане, пъту́ване, присти́гане, etc.
				plural = "ия"
			elseif rfind(lemma, "е́?$") then
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
		-- Detect has-vocative indicator.
		if accent_and_form_spec.voc then
			-- If explicit override for vocative, we have a vocative regardless.
			accent_spec.has_vocative = true
		elseif accent_spec.gender == "n" then
			-- Otherwise if neuter, no vocative even if (v) or (h) is used.
			accent_spec.has_vocative = false
		elseif accent_spec.gender == "f" and rfind(lemma, com.cons_c .. "$") then
			-- Otherwise if feminine and ending in a consonant, no vocative even if (v) or (h) is used.
			accent_spec.has_vocative = false
		elseif accent_spec.reducible_vocative or accent_spec.human then
			-- Otherwise, respect (v*) and (h). Note that (v) already sets has_vocative = true.
			accent_spec.has_vocative = true
		end
		-- Detect reducible indicators.
		if g == "m" and rfind(lemma, com.vowel_c .. AC .. "?зъм$") then
			accent_spec.reducible = true
			accent_spec.reducible_definite = true
			if accent_spec.has_vocative then
				accent_spec.reducible_vocative = true
			end
		end
		-- Detect no-def-sg indicator.
		if rfind(lemma, "^%u") and not accent_and_form_spec.def then
			accent_and_form_spec["-def"] = true
		end
		-- Detect no-count indicator.
		if accent_spec.human and not accent_and_form_spec.count then
			accent_and_form_spec["-count"] = true
		end
		-- Detect has-count indicator.
		-- (1) Yes if an explicit count override is given.
		accent_spec.has_count = accent_and_form_spec.count or (
			-- Otherwise:
			-- (2) No if -count is explicitly given.
			not accent_and_form_spec["-count"] and
			-- (3) Only masculine nouns ending in a consonant normally have a count form.
			accent_spec.gender == "m" and
			rfind(lemma, com.cons_c .. "$")
		)
	end
end


-- Call detect_adj_accent_and_form_spec() on all accent-and-form specs in ALTERNANT_MULTIWORD_SPEC.
local function detect_all_adj_accent_and_form_specs(alternant_multiword_spec)
	map_word_specs(alternant_multiword_spec, function(word_spec)
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			detect_adj_accent_and_form_spec(word_spec.lemma, accent_and_form_spec)
		end
	end)
end


-- Call detect_noun_accent_and_form_spec() on all accent-and-form specs in ALTERNANT_MULTIWORD_SPEC.
local function detect_all_noun_accent_and_form_specs(alternant_multiword_spec)
	map_word_specs(alternant_multiword_spec, function(word_spec)
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			detect_noun_accent_and_form_spec(word_spec.lemma, accent_and_form_spec)
		end
	end)
end


local function init_active_adj_slots()
	local active_slots = {}
	return active_slots
end


local function set_active_adj_slots(active_slots, accent_and_form_spec)
	if accent_and_form_spec.koj then
		active_slots.nom_m_sg = true
		active_slots.acc_m_sg = true
		active_slots.dat_m_sg = true
		active_slots.f_sg = true
		active_slots.n_sg = true
		active_slots.pl = true
	elseif accent_and_form_spec.chij then
		active_slots.m_sg = true
		active_slots.f_sg = true
		active_slots.n_sg = true
		active_slots.pl = true
	elseif accent_and_form_spec.dva then
		active_slots.ind_m_pl = true
		active_slots.def_m_pl = true
		active_slots.ind_fn_pl = true
		active_slots.def_fn_pl = true
	else
		active_slots.ind_m_sg = true
		active_slots.def_sub_m_sg = true
		active_slots.def_obj_m_sg = true
		active_slots.ind_f_sg = true
		active_slots.def_f_sg = true
		active_slots.ind_n_sg = true
		active_slots.def_n_sg = true
		active_slots.ind_pl = true
		active_slots.def_pl = true
		if not accent_and_form_spec.accent_spec.nocomp then
			active_slots.comp = true
		end
	end
	if accent_and_form_spec["-voc"] then
		active_slots.no_voc = true
	end
	if accent_and_form_spec.short then
		active_slots.short = true
	end
end


-- Determine overall active adjective slots.
local function compute_overall_active_adj_slots(alternant_multiword_spec)
	local active_slots = init_active_adj_slots()
	map_word_specs(alternant_multiword_spec, function(word_spec)
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			set_active_adj_slots(active_slots, accent_and_form_spec)
		end
	end)
	if not active_slots.no_voc then
		active_slots.voc_m_sg = true
	end
	return active_slots
end


local function init_active_noun_slots()
	local active_slots = {}
	-- Set the always-active slots.
	active_slots.ind_sg = true
	return active_slots
end


local function set_active_noun_slots(active_slots, accent_and_form_spec)
	-- NOTE: We currently treat singular and plural as always active, and
	-- separately calculate the overall number, which is passed into places
	-- like make_noun_table() to determine which slots to actually use.

	-- The calculations to determine whether there's a vocative and/or a count
	-- form were done in detect_noun_accent_and_form_spec().
	if accent_and_form_spec.accent_spec.has_vocative then
		active_slots.voc_sg = true
		active_slots.voc_pl = true
	end
	if accent_and_form_spec.accent_spec.has_count then
		active_slots.count = true
	end
	for _, case in ipairs(extra_noun_cases) do
		-- Adjectival noun overrides currently use acc_sg, gen_sg, dat_sg,
		-- while regular noun overrides just use acc, gen, dat.
		if accent_and_form_spec[case] or accent_and_form_spec[case .. "_sg"] then
			active_slots[case .. "_sg"] = true
		end
		if accent_and_form_spec[case .. "_pl"] then
			active_slots[case .. "_pl"] = true
		end
	end
	if accent_and_form_spec["-def"] then
		active_slots.no_def = true
	end
	if accent_and_form_spec["-pl"] then
		active_slots.no_pl = true
	end
	if accent_and_form_spec["-def_pl"] then
		active_slots.no_def_pl = true
	end
	if accent_and_form_spec.n then
		if not active_slots.n then
			active_slots.n = accent_and_form_spec.n
		elseif active_slots.n ~= accent_and_form_spec.n then
			active_slots.n = "both"
		end
	end
end


local function convert_active_noun_slots_to_active_adj_slots(active_noun_slots)
	local active_adj_slots = init_active_adj_slots()
	if active_noun_slots.voc_sg then
		active_adj_slots.voc_m_sg = true
	end
	return active_adj_slots
end


-- Determine overall active noun slots.
local function compute_overall_active_noun_slots(alternant_multiword_spec)
	local active_slots = init_active_noun_slots()
	map_word_specs(alternant_multiword_spec, function(word_spec)
		for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
			set_active_noun_slots(active_slots, accent_and_form_spec)
		end
	end)
	if not active_slots.no_def then
		active_slots.def_sub_sg = true
		active_slots.def_obj_sg = true
	end
	if not active_slots.no_pl then
		active_slots.ind_pl = true
		if not active_slots.no_def_pl then
			active_slots.def_pl = true
		end
	end
	return active_slots
end


-- Construct the plural of the lemma specified in WORD_SPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()), the plural ending (e.g. "ове"), and the accent indicator
-- (e.g. "a" or "d"). Return value is a string. This handles accenting the plural ending as necessary,
-- fetching the reduced stem if appropriate, removing final -ин if called for, and applying the
-- second palatalization if appropriate (e.g. ези́к -> ези́ци).
local function generate_noun_plural(word_spec, accent_spec, plural, accent)
	local ending = plural.plural
	if accent == "b" or accent == "c" then
		if accent == "b" and (ending == "ове" or ending == "ьове" or ending == "йове" or ending == "еве") or
			ending == "еса" or ending == "ена" then
			ending = ending .. AC
		else
			-- for any other plurals, put the stress on the first vowel if a stress isn't already present
			ending = com.maybe_stress_initial_syllable(ending)
		end
	end

	local stem = accent_spec.reducible and word_spec.reduced_stem or word_spec.stem
	
	if accent_spec.remove_in then
		local new_stem, removed = rsubb(stem, "и́?н$", "")
		if not removed then
			error("(ин) specified but stem '" .. stem .. "' doesn't end in -ин")
		end
		stem = com.maybe_stress_final_syllable(new_stem)
	end

	if not plural.double_plus and not rfind(word_spec.lemma, "нг$") and (
		-- ези́к -> ези́ци
		rfind(ending, "^и́?$") and rfind(word_spec.lemma, "[кгх]$") or
		-- ръка́ -> ръце́
		rfind(ending, "^е́?$") and rfind(word_spec.lemma, "[кгх]а́?$")
	) then
		local initial, last_cons = rmatch(stem, "^(.*)([кгх])$")
		if initial then
			return combine_stem_and_ending(initial .. com.second_palatalization[last_cons], ending, accent_spec)
		end
	end

	return combine_stem_and_ending(stem, ending, accent_spec)
end


-- Construct the definite singular of the lemma specified in WORD_SPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()) and the accent indicator (e.g. "a" or "d").
-- Return value is a string. This handles determining the appropriate ending (handling the
-- soft sign spec (ь) as needed), accenting the ending as necessary, and fetching the
-- reduced stem if appropriate.
local function generate_noun_definite_singular(word_spec, accent_spec, accent)
	local function stressed_ending()
		return accent == "b" or accent == "d"
	end
	if accent_spec.gender == "m" then
		if rfind(word_spec.lemma, "[ая]́?$") then
			return word_spec.lemma .. "та"
		elseif rfind(word_spec.lemma, "[ео]́?$") then
			return word_spec.lemma .. "то"
		else
			local ending
			if accent_spec.soft_sign then
				ending = stressed_ending() and "я́т" or "ят"
			elseif stressed_ending() then
				ending = "ъ́т"
			else
				ending = "ът"
			end
			local stem = accent_spec.reducible_definite and word_spec.reduced_stem or word_spec.stem
			return combine_stem_and_ending(stem, ending, accent_spec)
		end
	elseif accent_spec.gender == "f" then
		return combine_stem_and_ending(word_spec.lemma, stressed_ending() and "та́" or "та", accent_spec)
	else
		return combine_stem_and_ending(word_spec.lemma, "то", accent_spec)
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


-- Construct the count form of the lemma specified in WORD_SPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()). Return value is a string, or nil if no count
-- form can be constructed (not a masculine lemma ending in a consonant). This handles
-- determining the appropriate ending (handling the soft sign spec (ь) as needed) and
-- fetching the reduced stem if appropriate.
local function generate_noun_count_form(word_spec, accent_spec)
	if accent_spec.gender ~= "m" or not rfind(word_spec.lemma, com.cons_c .. "$") then
		return nil
	end
	local stem = accent_spec.reducible_count and word_spec.reduced_stem or word_spec.stem
	if accent_spec.soft_sign then
		return combine_stem_and_ending(stem, "я", accent_spec)
	else
		return combine_stem_and_ending(stem, "а", accent_spec)
	end
end


-- Construct the vocative of the lemma specified in WORD_SPEC, given the accent spec
-- (as returned by parse_noun_accent_spec()). Return value is a string, or nil if no vocative
-- form can be constructed. This applies the rules described in [[w:Bulgarian nouns]].
local function generate_noun_vocative(word_spec, accent_spec)
	if accent_spec.gender == "n" or not accent_spec.has_vocative then
		return nil
	end
	local lemma = word_spec.lemma
	if accent_spec.gender == "f" and rfind(lemma, com.cons_c .. "$") then
		return nil
	end
	local stem = accent_spec.reducible_vocative and word_spec.reduced_stem or word_spec.stem
	local ending
	if accent_spec.soft_sign then
		ending = "ю"
	elseif rfind(lemma, com.vowel_c .. AC .. "?я́?$") then
		ending = "йо"
	elseif rfind(lemma, "я́?$") then
		ending = "ьо"
	elseif rfind(lemma, "ца́?$") or rfind(lemma, "[рч]ка́?$") or rfind(lemma, "^%u.*ка́?$") then
		ending = "е"
	elseif rfind(lemma, "а́?$") or rfind(lemma, "[кчцх]$") or rfind(lemma, "и́?н$") then
		ending = "о"
	elseif rfind(lemma, "[гз]$") then
		return combine_stem_and_ending(rsub(stem, "[гз]$", "ж"), "е", accent_spec)
	else
		ending = "е"
	end
	return combine_stem_and_ending(stem, ending, accent_spec)
end


-- Construct the indefinite adjective forms.
local function generate_indefinite_adj_forms(formtable, accent_spec, accent, active_slots)
	local stem = accent_spec.stem
	local accent = accent == "b" and AC or ""
	iut.insert_form(formtable, "ind_f_sg",
		{form=combine_stem_and_ending(stem, (accent_spec.soft_sign and "я" or "а") .. accent, accent_spec, "is adj")})
	if accent_spec.ch then
		iut.insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem, "е" .. accent, accent_spec, "is adj")})
		iut.insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem, "о" .. accent, accent_spec, "is adj")})
	else
		iut.insert_form(formtable, "ind_n_sg",
			{form=combine_stem_and_ending(stem,
				((accent_spec.che or accent_spec.soft_sign_i) and "е" or accent_spec.soft_sign and "ьо" or "о") .. accent,
				accent_spec, "is adj")})
	end
	local ind_pl = combine_stem_and_ending(stem, "и" .. accent, accent_spec, "is adj")
	iut.insert_form(formtable, "ind_pl", {form=ind_pl})
	if active_slots.voc_m_sg then
		iut.insert_form(formtable, "voc_m_sg", {form=ind_pl})
		iut.insert_form(formtable, "voc_m_sg", {form=ind_pl .. "й"})
	end
end


-- Construct the definite adjective forms based on the indefinite ones.
local function generate_definite_adj_forms(formtable, include_definite)
	if include_definite then
		iut.insert_forms(formtable, "def_sub_m_sg", iut.map_forms(formtable["ind_pl"],
			function(form) return form .. "ят" end))
		iut.insert_forms(formtable, "def_obj_m_sg", iut.map_forms(formtable["ind_pl"],
			function(form) return form .. "я" end))
		iut.insert_forms(formtable, "def_f_sg", iut.map_forms(formtable["ind_f_sg"],
			function(form) return form .. "та" end))
		iut.insert_forms(formtable, "def_n_sg", iut.map_forms(formtable["ind_n_sg"],
			function(form) return form .. "то" end))
		iut.insert_forms(formtable, "def_pl", iut.map_forms(formtable["ind_pl"],
			function(form) return form .. "те" end))
	else
		iut.insert_forms(formtable, "def_sub_m_sg", formtable["ind_m_sg"])
		iut.insert_forms(formtable, "def_obj_m_sg", formtable["ind_m_sg"])
		iut.insert_forms(formtable, "def_f_sg", formtable["ind_f_sg"])
		iut.insert_forms(formtable, "def_n_sg", formtable["ind_n_sg"])
		iut.insert_forms(formtable, "def_pl", formtable["ind_pl"])
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
					iut.insert_form_into_list(retforms, {form=f.form, footnotes=overriding_spec.footnotes})
				end
			else
				form = rsub(form, "~~", stem)
				form = rsub(form, "~", lemma)
				iut.insert_form_into_list(retforms, {form=form, footnotes=overriding_spec.footnotes})
			end
		end
		return retforms
	end
end


-- Decline a single adjective term in WORD_SPEC (an object as returned by parse_simplified_specification())
-- corresponding to the accent-and-form spec in `accent_and_form_spec` (see parse_noun_accent_and_form_specs()).
-- This sets the form values in `WORD_SPEC.forms` (and `WORD_SPEC.compforms` and `WORD_SPEC.supforms`
-- if the adjective has comparative forms) for all slots. (If a given slot has no values,
-- it will not be present in `WORD_SPEC.forms`.) If `as_noun` is true, we're declining an adjectival noun
-- rather than an adjective as such.
local function decline_one_adj(word_spec, accent_and_form_spec, active_slots, active_noun_slots, include_definite)
	local accent_spec = accent_and_form_spec.accent_spec
	local lemma = word_spec.lemma
	local stem = accent_spec.stem
	local formtable = {[
		accent_and_form_spec.dva and "ind_m_pl" or
		accent_and_form_spec.koj and "nom_m_sg" or
		accent_and_form_spec.chij and "m_sg" or
		"ind_m_sg"
	] = {{form=lemma}}}
	for _, accent in ipairs(accent_spec.accents) do
		generate_indefinite_adj_forms(formtable, accent_spec, accent, active_slots)
	end
	generate_definite_adj_forms(formtable, include_definite)
	if active_noun_slots then
		local noun_formtable = {}
		local function copy_forms(forms_to_copy)
			for from_form, to_forms in pairs(forms_to_copy) do
				if type(to_forms) ~= "table" then
					to_forms = {to_forms}
				end
				for _, to_form in ipairs(to_forms) do
					if active_noun_slots[to_form] then
						iut.insert_forms(noun_formtable, to_form, formtable[from_form])
					end
				end
			end
		end
		if active_noun_slots.n ~= "pl" then
			local forms_to_copy =
				accent_spec.gender == "m" and masc_adj_to_noun_slots or
				accent_spec.gender == "f" and fem_adj_to_noun_slots or
				neut_adj_to_noun_slots
			copy_forms(forms_to_copy)
		end
		if active_noun_slots.n ~= "sg" then
			copy_forms(pl_adj_to_noun_slots)
		end
		for slot, _ in pairs(noun_slots) do
			iut.insert_forms(word_spec.forms, slot, handle_overriding_forms(lemma, stem, noun_formtable[slot],
				accent_and_form_spec[slot]))
		end
	else
		for slot, _ in pairs(adj_slots) do
			local forms = handle_overriding_forms(lemma, stem, formtable[slot], accent_and_form_spec[slot])
			iut.insert_forms(word_spec.forms, slot, forms)
			if active_slots.comp and not accent_spec.nocomp then
				if not word_spec.compforms then
					word_spec.compforms = {}
				end
				iut.insert_forms(word_spec.compforms, slot,
					iut.map_forms(forms, function(form) return "по́-" .. form end))
				if not word_spec.supforms then
					word_spec.supforms = {}
				end
				iut.insert_forms(word_spec.supforms, slot,
					iut.map_forms(forms, function(form) return "на́й-" .. form end))
			end
		end
	end
end


-- Decline the adjective in WORD_SPEC (an object as returned by parse_simplified_specification()).
-- This sets the form values in `WORD_SPEC.forms` (and `WORD_SPEC.compforms` and `WORD_SPEC.supforms`
-- if the adjective has comparative forms) for all slots. (If a given slot has no values,
-- it will not be present in `WORD_SPEC.forms`.)
local function decline_adj(word_spec, active_slots, include_definite)
	for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
		decline_one_adj(word_spec, accent_and_form_spec, active_slots, nil, include_definite)
	end
end


-- Decline a single noun term in WORD_SPEC (an object as returned by parse_simplified_specification())
-- corresponding to the accent-and-form spec in `accent_and_form_spec` (see parse_noun_accent_and_form_specs()).
-- This sets the form values in `WORD_SPEC.forms` for all slots. (If a given slot has no values,
-- it will not be present in `WORD_SPEC.forms`.)
local function decline_one_noun(word_spec, accent_and_form_spec, active_slots, include_definite)
	local lemma = word_spec.lemma
	local stem = word_spec.stem
	if active_slots.n == "pl" then
		for _, overriding_form in ipairs(noun_overriding_forms) do
			if not overriding_form:find("_pl$") and accent_and_form_spec[overriding_form] then
				error("'/" .. overriding_form .. ":' not allowed for plurale tantum")
			end
		end

		-- Maybe set indefinite plural.
		local indefinite_plurals = {{form=lemma}}
		if active_slots.ind_pl then
			iut.insert_forms(word_spec.forms, "ind_pl",
				handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec.ind_pl))
		end

		-- Maybe set definite plural.
		if active_slots.def_pl then
			iut.insert_forms(word_spec.forms, "def_pl",
				handle_overriding_forms(lemma, stem,
					include_definite and iut.map_forms(indefinite_plurals, generate_noun_definite_plural) or indefinite_plurals,
					accent_and_form_spec.def_pl))
		end

		-- Maybe set "extra cases".
		for _, case in ipairs(extra_noun_cases) do
			local pl_slot = case .. "_pl"
			if active_slots[pl_slot] then
				iut.insert_forms(word_spec.forms, pl_slot, handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec[pl_slot]))
			end
		end
	else
		local accent_spec = accent_and_form_spec.accent_spec

		-- Always generate indefinite singulars since may be needed for the "extra cases" below.
		local indefinite_singulars = {{form = lemma}}

		-- Always generate indefinite plurals since may be needed for the "extra cases" below.
		local indefinite_plurals = {}
		for _, plspec in ipairs(accent_spec.plurals) do
			for _, accent in ipairs(accent_spec.accents) do
				iut.insert_form_into_list(indefinite_plurals,
					{form=generate_noun_plural(word_spec, accent_spec, plspec, accent), footnotes=plspec.footnotes}
				)
			end
		end
		indefinite_plurals = handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec.pl)

		-- Maybe set indefinite singular.
		if active_slots.ind_sg then
			iut.insert_forms(word_spec.forms, "ind_sg",
				handle_overriding_forms(lemma, stem, indefinite_singulars, accent_and_form_spec.ind))
		end

		-- Maybe set definite singular.
		if active_slots.def_sub_sg or active_slots.def_obj_sg then
			local definite_singulars
			if include_definite then
				definite_singulars = {}
				for _, accent in ipairs(accent_spec.accents) do
					iut.insert_form_into_list(definite_singulars,
						{form=generate_noun_definite_singular(word_spec, accent_spec, accent)}
					)
				end
			else
				definite_singulars = indefinite_singulars
			end
			definite_singulars = handle_overriding_forms(lemma, stem, definite_singulars, accent_and_form_spec.def)
			if active_slots.def_sub_sg then
				iut.insert_forms(word_spec.forms, "def_sub_sg",
					handle_overriding_forms(lemma, stem, definite_singulars, accent_and_form_spec.def_sub))
			end
			if active_slots.def_obj_sg then
				iut.insert_forms(word_spec.forms, "def_obj_sg",
					handle_overriding_forms(lemma, stem,
						include_definite and iut.map_forms(definite_singulars, generate_noun_definite_objective_singular) or
						definite_singulars,
						accent_and_form_spec.def_obj))
			end
		end

		-- Maybe set indefinite plural.
		if active_slots.ind_pl then
			iut.insert_forms(word_spec.forms, "ind_pl",
				handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec.ind_pl))
		end

		-- Maybe set definite plural.
		if active_slots.def_pl then
			iut.insert_forms(word_spec.forms, "def_pl",
				handle_overriding_forms(lemma, stem,
					include_definite and iut.map_forms(indefinite_plurals, generate_noun_definite_plural) or
					indefinite_plurals,
					accent_and_form_spec.def_pl))
		end

		-- Maybe set count.
		if active_slots.count then
			local count_forms = {}
			iut.insert_form_into_list(count_forms, {form=generate_noun_count_form(word_spec, accent_spec)})
			iut.insert_forms(word_spec.forms, "count", handle_overriding_forms(lemma, stem, count_forms, accent_and_form_spec.count))
		end

		-- Maybe set vocative singular.
		if active_slots.voc_sg then
			local vocatives = {}
			iut.insert_form_into_list(vocatives, {form=generate_noun_vocative(word_spec, accent_spec)})
			iut.insert_forms(word_spec.forms, "voc_sg", handle_overriding_forms(lemma, stem, vocatives, accent_and_form_spec.voc))
		end

		-- Maybe set vocative plural.
		if active_slots.voc_pl then
			iut.insert_forms(word_spec.forms, "voc_pl", handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec.voc_pl))
		end

		-- Maybe set "extra cases".
		for _, case in ipairs(extra_noun_cases) do
			local sg_slot = case .. "_sg"
			if active_slots[sg_slot] then
				iut.insert_forms(word_spec.forms, sg_slot, handle_overriding_forms(lemma, stem, indefinite_singulars, accent_and_form_spec[case]))
			end
			local pl_slot = case .. "_pl"
			if active_slots[pl_slot] then
				iut.insert_forms(word_spec.forms, pl_slot, handle_overriding_forms(lemma, stem, indefinite_plurals, accent_and_form_spec[pl_slot]))
			end
		end
	end
end


-- Decline the noun in WORD_SPEC (an object as returned by parse_simplified_specification()).
-- This sets the form values in `WORD_SPEC.forms` for all slots. (If a given slot has no values,
-- it will not be present in `WORD_SPEC.forms`.)
local function decline_noun(word_spec, active_slots, include_definite)
	for _, accent_and_form_spec in ipairs(word_spec.accent_and_form_specs) do
		if accent_and_form_spec.accent_spec.is_adj then
			local active_adj_slots = convert_active_noun_slots_to_active_adj_slots(active_slots)
			decline_one_adj(word_spec, accent_and_form_spec, active_adj_slots, active_slots, include_definite)
		else
			decline_one_noun(word_spec, accent_and_form_spec, active_slots, include_definite)
		end
	end
end


local decline_multiword_or_alternant_multiword_spec


-- Decline the noun or adjective alternants in ALTERNANT_SPEC (an object as returned by
-- parse_simplified_specification_allowing_alternants()). This sets the form values
-- in `ALTERNANT_SPEC.forms` for all slots. (If a given slot has no values, it will
-- not be present in `ALTERNANT_SPEC.forms`). It also sets `ALTERNANT_SPEC.forms.lemma`,
-- which is a list of strings to use as lemmas (e.g. in the title of the generated table
-- and in accelerators).
local function decline_alternants(alternant_spec, active_slots, is_adj, include_definite)
	alternant_spec.forms = {}
	if active_slots.comp then
		alternant_spec.compforms = {}
		alternant_spec.supforms = {}
	end
	local include_definite_at_end = include_definite
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		include_definite_at_end = decline_multiword_or_alternant_multiword_spec(
			multiword_spec, active_slots, is_adj, include_definite)
		for slot, _ in pairs(active_slots) do
			iut.insert_forms(alternant_spec.forms, slot, multiword_spec.forms[slot])
			if is_adj and active_slots.comp then
				iut.insert_forms(alternant_spec.compforms, slot, multiword_spec.compforms[slot])
				iut.insert_forms(alternant_spec.supforms, slot, multiword_spec.supforms[slot])
			end
		end
	end
	return include_definite_at_end
end


local function append_forms(formtable, slot, forms, before_text)
	local old_forms = formtable[slot]
	if #forms == 1 then
		-- If there's only one new form, destructively modify the existing
		-- forms and notes for this new form and its footnotes.
		local form = forms[1]
		for _, old_form in ipairs(old_forms) do
			old_form.form = old_form.form .. before_text .. form.form
			if form.footnotes and #form.footnotes > 0 then
				if not old_form.footnotes then
					old_form.footnotes = {}
				end
				for _, footnote in ipairs(form.footnotes) do
					m_table.insertIfNot(old_form.footnotes, footnote)
				end
			end
		end
	else
		-- If there are multiple new forms, we need to loop over all
		-- combinations of new and old forms. In that case, use a new table
		-- for the combined forms.
		local ret_forms = {}
		for _, old_form in ipairs(old_forms) do
			for _, form in ipairs(forms) do
				-- Do a shallow copy of the footnotes because we may modify them in-place.
				local new_form = {form=old_form.form .. before_text .. form.form,
					footnotes=m_table.shallowcopy(old_form.footnotes)}
				if form.footnotes and #form.footnotes > 0 then
					if not new_form.footnotes then
						new_form.footnotes = {}
					end
					for _, footnote in ipairs(form.footnotes) do
						m_table.insertIfNot(new_form.footnotes, footnote)
					end
				end
				table.insert(ret_forms, new_form)
			end
		end
		formtable[slot] = ret_forms
	end
end


decline_multiword_or_alternant_multiword_spec = function(multiword_spec, active_slots, is_adj, include_definite)
	multiword_spec.forms = {}
	if active_slots.comp then
		multiword_spec.compforms = {}
		multiword_spec.supforms = {}
	end
	for slot, _ in pairs(active_slots) do
		multiword_spec.forms[slot] = {{form=""}}
		if active_slots.comp then
			multiword_spec.compforms[slot] = {{form=""}}
			multiword_spec.supforms[slot] = {{form=""}}
		end
	end

	local is_alternant_multiword = not not multiword_spec.alternant_or_word_specs
	for _, word_spec in ipairs(is_alternant_multiword and multiword_spec.alternant_or_word_specs or multiword_spec.word_specs) do
		if word_spec.alternants then
			include_definite = decline_alternants(word_spec, active_slots, is_adj, include_definite)
		elseif is_adj then
			decline_adj(word_spec, active_slots, include_definite)
			include_definite = false
		else
			decline_noun(word_spec, active_slots, include_definite)
			include_definite = not word_spec.accent_and_form_specs[1].accent_spec.is_adj
		end
		for slot, _ in pairs(active_slots) do
			if word_spec.forms[slot] then
				append_forms(multiword_spec.forms, slot, word_spec.forms[slot], word_spec.before_text)
			end
			if word_spec.compforms and word_spec.compforms[slot] then
				append_forms(multiword_spec.compforms, slot, word_spec.compforms[slot], word_spec.before_text)
			end
			if word_spec.supforms and word_spec.supforms[slot] then
				append_forms(multiword_spec.supforms, slot, word_spec.supforms[slot], word_spec.before_text)
			end
		end
	end
	if multiword_spec.post_text ~= "" then
		local pseudoform = {{form=""}}
		for slot, _ in pairs(active_slots) do
			append_forms(multiword_spec.forms, slot, pseudoform, multiword_spec.post_text)
			if active_slots.comp then
				append_forms(multiword_spec.compforms, slot, pseudoform, multiword_spec.post_text)
				append_forms(multiword_spec.supforms, slot, pseudoform, multiword_spec.post_text)
			end
		end
	end

	if is_alternant_multiword then
		multiword_spec.n = active_slots.n
		local lemma_slot =
			multiword_spec.forms.ind_m_pl and "ind_m_pl" or -- два
			multiword_spec.forms.nom_m_sg and "nom_m_sg" or -- кой, то́зи, etc.
			multiword_spec.forms.m_sg and "m_sg" or -- чий, какъ́в, такъ́в, etc.
			is_adj and "ind_m_sg" or
			multiword_spec.n == "pl" and "ind_pl" or
			"ind_sg"
		multiword_spec.forms.lemma = {}
		for _, form in ipairs(multiword_spec.forms[lemma_slot]) do
			m_table.insertIfNot(multiword_spec.forms.lemma, form.form)
		end
	end

	return include_definite
end


-- Convert `ALTERNANT_MULTIWORD_SPEC.forms[SLOT]` (for ALTERNANT_MULTIWORD_SPEC as returned by
-- parse_simplified_specification_allowing_alternants()) for all slots into displayable text.
-- This also sets ALTERNANT_MULTIWORD_SPEC.combined_def_sg to true if the definite subjective and
-- objective singular forms are the same (and hence should be combined in the generated table),
-- and sets ALTERNANT_MULTIWORD_SPEC.forms.footnote to the combined string to insert as a footnote
-- (if there are no footnotes, it will be the empty string).
local function show_forms(alternant_multiword_spec, is_adj)
	local lemmas = {}
	for _, lemma in ipairs(alternant_multiword_spec.forms.lemma) do
		table.insert(lemmas, com.remove_monosyllabic_stress(lemma))
	end
	local accel_lemma = lemmas[1]
	alternant_multiword_spec.forms.lemma = table.concat(lemmas, ", ")

	local function get_slot_to_accel_form(combined_def_sg)
		return function(slot)
			local accel_form = is_adj and adj_slots[slot] or noun_slots[slot]
			-- HACK!
			if combined_def_sg and slot == "def_sub_sg" then
				accel_form = "def|s"
			end
			return accel_form
		end
	end

	local footnote_obj = com.init_footnote_obj()

	if is_adj then
		local slot_to_accel_form = get_slot_to_accel_form(false)
		com.display_forms(footnote_obj, alternant_multiword_spec.forms, alternant_multiword_spec.forms,
			adj_slots, false, accel_lemma, slot_to_accel_form)
		if alternant_multiword_spec.compforms then
			com.display_forms(footnote_obj, alternant_multiword_spec.compforms, alternant_multiword_spec.compforms,
				adj_slots, false, accel_lemma, slot_to_accel_form)
		end
		if alternant_multiword_spec.supforms then
			com.display_forms(footnote_obj, alternant_multiword_spec.supforms, alternant_multiword_spec.supforms,
				adj_slots, false, accel_lemma, slot_to_accel_form)
		end
	else
		-- For def_sub_sg and def_obj_sg, first compute "raw" (unlinked) forms so we can
		-- compare them properly; linked forms have accelerator info in them which differs
		-- between sub and obj.
		local raw_forms = {}
		com.display_forms(footnote_obj, alternant_multiword_spec.forms, raw_forms, {"def_sub_sg", "def_obj_sg"},
			"is list", accel_lemma, get_slot_to_accel_form(true), "raw")
		-- Then generate the linked forms, using a special accelerator form if the def_sub_sg and def_obj_sg are the same.
		alternant_multiword_spec.combined_def_sg = raw_forms.def_sub_sg == raw_forms.def_obj_sg
		com.display_forms(footnote_obj, alternant_multiword_spec.forms, alternant_multiword_spec.forms, noun_slots,
			false, accel_lemma, get_slot_to_accel_form(alternant_multiword_spec.combined_def_sg))
	end
	if alternant_multiword_spec.footnote then
		table.insert(footnote_obj.notes, alternant_multiword_spec.footnote)
	end
	alternant_multiword_spec.forms.footnote = table.concat(footnote_obj.notes, "<br />")
end


-- Generate the displayable table of all noun forms, given ALTERNANT_MULTIWORD_SPEC (as returned
-- by parse_alternant_multiword_spec()) where show_forms() has already been called to convert
-- `ALTERNANT_MULTIWORD_SPEC.forms` into a table of strings.
local function make_noun_table(alternant_multiword_spec)
	local num = alternant_multiword_spec.n
	local forms = alternant_multiword_spec.forms

	local table_begin = [=[
<div class="NavFrame" style="width: 50em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
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
<div class="NavFrame" style="width: 30em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
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
<div class="NavFrame" style="width: 30em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
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
			(alternant_multiword_spec.combined_def_sg and table_sg_cont_def_combined or table_sg_cont_def_split) ..
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
			(alternant_multiword_spec.combined_def_sg and table_cont_def_combined or table_cont_def_split) ..
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

	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	forms.title = alternant_multiword_spec.title or "Declension of " .. forms.lemma
	return m_string_utilities.format(table_spec, forms)
end


-- Generate the displayable table of all adjective forms, given ALTERNANT_MULTIWORD_SPEC (as returned
-- by parse_alternant_multiword_spec()) where show_forms() has already been called to convert
-- `ALTERNANT_MULTIWORD_SPEC.forms` into a table of strings.
local function make_adj_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	local table_normal_koj_begin = [=[
<div class="NavFrame" style="width: 50em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 33%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | masculine
! style="font-size: 90%; background: #d9ebff;" | feminine
! style="font-size: 90%; background: #d9ebff;" | neuter
! style="font-size: 90%; background: #d9ebff;" | plural
|-
]=]

	local table_cont_indef_def = [=[
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
]=]

	local table_cont_koj = [=[
! style="font-size: 90%; background: #eff7ff;" | nominative
| {nom_m_sg}
| rowspan="3" | {f_sg}
| rowspan="3" | {n_sg}
| rowspan="3" | {pl}
|-
! style="font-size: 90%; background: #eff7ff;" | accusative
| {acc_m_sg}
|-
! style="font-size: 90%; background: #eff7ff;" | dative
| {dat_m_sg}
]=]

	local table_cont_short = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | short form
| colspan="4" | {short}
]=]

	local table_cont_voc = [=[
|-
! style="font-size: 90%; background: #eff7ff;" | extended<br />(vocative form)
| {voc_m_sg}
]=]

	local table_dva_begin = [=[
<div class="NavFrame" style="width: 25em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="width: 33%; background: #d9ebff; " |
! style="font-size: 90%; background: #d9ebff;" | masculine
! style="font-size: 90%; background: #d9ebff;" | feminine/<br />neuter
|-
! style="font-size: 90%; background: #eff7ff;" | indefinite
| {ind_m_pl}
| {ind_fn_pl}
|-
! style="font-size: 90%; background: #eff7ff;" | definite
| {def_m_pl}
| {def_fn_pl}
]=]

	local table_chij_begin = [=[
<div class="NavFrame" style="width: 35em;">
<div class="NavHead" style="background: #eff7ff;">{title}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse: collapse; background: #F9F9F9; width: 100%;" class="inflection-table"
! style="font-size: 90%; background: #d9ebff;" | masculine
! style="font-size: 90%; background: #d9ebff;" | feminine
! style="font-size: 90%; background: #d9ebff;" | neuter
! style="font-size: 90%; background: #d9ebff;" | plural
|-
| {m_sg}
| {f_sg}
| {n_sg}
| {pl}
]=]

	local table_end = [=[
|{\cl}{notes_clause}</div></div>]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	local special_title = alternant_multiword_spec.title or "Declension of " .. forms.lemma
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	if forms.ind_m_pl ~= "—" then -- два
		local table_spec = table_dva_begin .. table_end
		forms.title = special_title
		return m_string_utilities.format(table_spec, forms)
	elseif forms.nom_m_sg ~= "—" then -- кой, etc.
		local table_spec = table_normal_koj_begin .. table_cont_koj .. table_end
		forms.title = special_title
		return m_string_utilities.format(table_spec, forms)
	elseif forms.m_sg ~= "—" then -- чий, etc.
		local table_spec = table_chij_begin .. table_end
		forms.title = special_title
		return m_string_utilities.format(table_spec, forms)
	else
		local table_spec = table_normal_koj_begin ..
			table_cont_indef_def ..
			(forms.short ~= "—" and table_cont_short or "") ..
			(forms.voc_m_sg ~= "—" and table_cont_voc or "") ..
			table_end
		if alternant_multiword_spec.compforms or alternant_multiword_spec.supforms then
			forms.title = alternant_multiword_spec.title or "Positive forms of " .. forms.lemma
		else
			forms.title = special_title .. " (no comparative)"
		end
		local postable = m_string_utilities.format(table_spec, forms)
		local comptable = ""
		local suptable = ""
		if alternant_multiword_spec.compforms then
			alternant_multiword_spec.compforms.notes_clause = forms.notes_clause
			alternant_multiword_spec.compforms.title = "Comparative forms of " .. forms.lemma
			comptable = m_string_utilities.format(table_spec, alternant_multiword_spec.compforms)
		end
		if alternant_multiword_spec.supforms then
			alternant_multiword_spec.supforms.notes_clause = forms.notes_clause
			alternant_multiword_spec.supforms.title = "Superlative forms of " .. forms.lemma
			suptable = m_string_utilities.format(table_spec, alternant_multiword_spec.supforms)
		end
		return postable .. comptable .. suptable
	end
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, only "|n=NUMBER"). This is for use by bots.
local function concat_forms(alternant_multiword_spec, include_props, is_adj)
	local ins_text = {}
	local n = alternant_multiword_spec.n
	local function skip_slot(slot)
		return n == "sg" and rfind(slot, "_pl$") or n == "pl" and (slot == "count" or rfind(slot, "_sg$"))
	end
	for slot, _ in pairs(is_adj and adj_slots or noun_slots) do
		if not skip_slot(slot) then
			local formtext = com.concat_forms_in_slot(alternant_multiword_spec.forms[slot])
			if formtext then
				table.insert(ins_text, slot .. "=" .. formtext)
			end
		end
	end
	for _, slot in ipairs(is_adj and potential_adj_lemma_slots or potential_noun_lemma_slots) do
		if not skip_slot(slot) then
			slot = "linked_" .. slot
			local formtext = com.concat_forms_in_slot(alternant_multiword_spec.forms[slot])
			if formtext then
				table.insert(ins_text, slot .. "=" .. formtext)
			end
		end
	end
	if include_props then
		if is_adj then
			table.insert(ins_text, "comp=" .. (alternant_multiword_spec.comparable and "1" or "0"))
		else
			if alternant_multiword_spec.n then
				table.insert(ins_text, "n=" .. alternant_multiword_spec.n)
			end
		end
	end
	return table.concat(ins_text, "|")
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in
-- `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a slot, the
-- slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
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

	pos = args.pos or pos -- args.pos only set when from_headword
	
	local alternant_multiword_spec = parse_alternant_multiword_spec(args[1])
	check_lemma_stress(alternant_multiword_spec)
	detect_all_noun_accent_and_form_specs(alternant_multiword_spec)
	local active_slots = compute_overall_active_noun_slots(alternant_multiword_spec)
	construct_noun_stems(alternant_multiword_spec)
	decline_multiword_or_alternant_multiword_spec(alternant_multiword_spec, active_slots, false,
		"include definite")
	alternant_multiword_spec.forms.lemma = args.lemma and #args.lemma > 0 and args.lemma or alternant_multiword_spec.forms.lemma
	alternant_multiword_spec.title = args.title
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline an adjective given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in
-- `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a slot, the slot
-- key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
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

	pos = args.pos or pos -- args.pos only set when from_headword
	
	local alternant_multiword_spec = parse_alternant_multiword_spec(args[1], "is adj")
	check_lemma_stress(alternant_multiword_spec)
	detect_all_adj_accent_and_form_specs(alternant_multiword_spec)
	local active_slots = compute_overall_active_adj_slots(alternant_multiword_spec)
	construct_adj_stems(alternant_multiword_spec)
	decline_multiword_or_alternant_multiword_spec(alternant_multiword_spec, active_slots, "is adj",
		"include definite")
	alternant_multiword_spec.forms.lemma = args.lemma and #args.lemma > 0 and args.lemma or alternant_multiword_spec.forms.lemma
	alternant_multiword_spec.title = args.title
	return alternant_multiword_spec
end


-- Main entry point for nouns. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show_noun(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_noun_forms(parent_args, "nouns")
	show_forms(alternant_multiword_spec)
	return make_noun_table(alternant_multiword_spec)
end


-- Main entry point for adjectives. Template-callable function to parse and decline an adjective given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show_adj(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_adj_forms(parent_args, "adjectives")
	show_forms(alternant_multiword_spec, "is adj")
	return make_adj_table(alternant_multiword_spec)
end


-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|n=NUMBER"). This is for use by bots.
function export.generate_noun_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_noun_forms(parent_args, "nouns")

	return concat_forms(alternant_multiword_spec, include_props)
end


-- Template-callable function to parse and decline an adjective given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|comp=1" if comparable). This is for use by bots.
function export.generate_adj_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_adj_forms(parent_args, "adjectives")

	return concat_forms(alternant_multiword_spec, include_props)
end


return export
