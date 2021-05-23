-- This module contains code for Italian headword templates.
-- Templates covered are it-adj, it-noun and it-proper noun.
-- See [[Module:it-conj]] for Italian conjugation templates.
local export = {}
local pos_functions = {}

local m_links = require("Module:links")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local unfd = mw.ustring.toNFD

local lang = require("Module:languages").getByCode("it")

local V = "[aeiou]"
local NV = "[^aeiou]"
local AV = "[àèéìòóù]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

-- The main entry point.
-- FIXME: Convert itadj, itnoun, itprop to go through this.
function export.show(frame)
	local tracking_categories = {}

	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["id"] = {},
		["sort"] = {},
	}

	local parargs = frame:getParent().args

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)
	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args["head"],
		genders = {},
		inflections = {},
		id = args["id"],
		sort_key = args["sort"],
	}

	if args["suff"] then
		data.pos_category = "suffixes"

		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame)
	end

	if args["json"] then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang)
end

function export.itadj(frame)
	local params = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
		
		["head"] = {},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {lang = lang, pos_category = "adjectives", categories = {}, sort_key = args["sort"], heads = {args["head"]}, genders = {}, inflections = {}}
	
	local stem = args[1]
	local end1 = args[2]
	
	if not stem then -- all specified
		data.heads = args[2]
		data.inflections = {
			{label = "feminine singular", args[3]},
			{label = "masculine plural", args[4]},
			{label = "feminine plural", args[5]}
		}
	elseif not end1 then -- no ending vowel parameters - generate default
		data.inflections = {
			{label = "feminine singular", stem .. "a"},
			{label = "masculine plural", make_plural(stem .. "o","m")},
			{label = "feminine plural", make_plural(stem .. "a","f")}
		}
	else
		local end2 = args[3] or error("Either 0, 2 or 4 vowel endings should be supplied!")
		local end3 = args[4]
		
		if not end3 then -- 2 ending vowel parameters - m and f are identical
			data.inflections = {
				{label = "masculine and feminine plural", stem .. end2}
			}
		else -- 4 ending vowel parameters - specify exactly
			local end4 = args[5] or error("Either 0, 2 or 4 vowel endings should be supplied!")
			data.inflections = {
				{label = "feminine singular", stem .. end2},
				{label = "masculine plural", stem .. end3},
				{label = "feminine plural", stem .. end4}
			}
		end
	end
	
	return require("Module:headword").full_headword(data)
end

local allowed_genders = require("Module:table").listToSet(
	{"m", "f", "mf", "mfbysense", "m-p", "f-p", "mf-p", "mfbysense-p", "?", "?-p"}
)

function export.itnoun(frame)
	local PAGENAME = mw.title.getCurrentTitle().text
	
	local params = {
		[1] = {list = "g", default = "?"},
		[2] = {list = "pl"},
		
		["head"] = {list = true},
		["m"] = {list = true},
		["mpl"] = {list = true},
		["f"] = {list = true},
		["fpl"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	local head = data.heads[1] and require("Module:links").remove_links(data.heads[1]) or PAGENAME
	-- Plural
	if is_plurale_tantum then
		if #args[2] > 0 then
			error("Can't specify plurals of plurale tantum noun")
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		local plural = args[2][1]
		
		if not plural and #args["mpl"] == 0 and #args["fpl"] == 0 then
			args[2][1] = make_plural(head, data.genders[1])
		end
		
		if plural == "~" then
			table.insert(data.inflections, {label = glossary_link("uncountable")})
			table.insert(data.categories, "Italian uncountable nouns")
		else
			table.insert(data.categories, "Italian countable nouns")
		end
		
		if plural == "-" then
			table.insert(data.inflections, {label = glossary_link("invariable")})
		end
		
		if plural ~= "-" and plural ~= "~" and #args[2] > 0 then
			args[2].label = "plural"
			args[2].accel = {form = "p"}
			table.insert(data.inflections, args[2])
		end
	end
	
	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	if #args["mpl"] > 0 then
		args["mpl"].label = "masculine plural"
		table.insert(data.inflections, args["mpl"])
	end

	if #args["fpl"] > 0 then
		args["fpl"].label = "feminine plural"
		table.insert(data.inflections, args["fpl"])
	end

	-- Category
	if head:find("o$") and data.genders[1] == "f" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	if head:find("a$") and data.genders[1] == "m" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	return require("Module:headword").full_headword(data)
end

-- Generate a default plural form, which is correct for most regular nouns
function make_plural(word, gender)
	-- If there are spaces in the term, then we can't reliably form the plural.
	-- Return nothing instead.
	if word:find(" ") then
		return nil
	elseif word:find("io$") then
		word = word:gsub("io$", "i")
	elseif word:find("ologo$") then
		word = word:gsub("o$", "i")
	elseif word:find("[cg]o$") then
		word = word:gsub("o$", "hi")
	elseif word:find("o$") then
		word = word:gsub("o$", "i")
	elseif word:find("[cg]a$") then
		word = word:gsub("a$", (gender == "m" and "hi" or "he"))
	elseif word:find("[cg]ia$") then
		word = word:gsub("ia$", "e")
	elseif word:find("a$") then
		word = word:gsub("a$", (gender == "m" and "i" or "e"))
	elseif word:find("e$") then
		word = word:gsub("e$", "i")
	end
	return word
end

-- Generate a default feminine form
function make_feminine(word, gender)
	if word:find("o$") then
		return word:gsub("o$", "a")
	else
		return word
	end
end

function export.itprop(frame)
	local params = {
		[1] = {list = "g", default = "?"},

		["head"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "proper nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	if is_plurale_tantum then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	end

	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	return require("Module:headword").full_headword(data)
end


local function base_default_verb_forms(base, lemma)
	local is_pronominal = false
	-- The particles that can go after a verb are:
	-- * la, le
	-- * ne
	-- * ci, vi (sometimes in the form ce, ve)
	-- * si (sometimes in the form se)
	-- Observed combinations:
	--   * ce + la: [[avercela]] "to be angry (at someone)", [[farcela]] "to make it, to succeed",
	--              [[mettercela tutta]] "to put everything (into something)"
	--   * se + la: [[sbrigarsela]] "to deal with", [[bersela]] "to naively believe in",
	--              [[sentirsela]] "to have the courage to face (a difficult situation)",
	--              [[spassarsela]] "to live it up", [[svignarsela]] "to scurry away",
	--              [[squagliarsela]] "to vamoose, to clear off", [[cercarsela]] "to be looking for (trouble etc.)",
	--              [[contarsela]] "to have a distortedly positive self-image; to chat at length",
	--              [[dormirsela]] "to be fast asleep", [[filarsela]] "to slip away, to scram",
	--              [[giostrarsela]] "to get away with; to turn a situation to one's advantage",
	--              [[cavarsela]] "to get away with; to get out of (trouble); to make the best of; to manage (to do); to be good at",
	--              [[meritarsela]] "to get one's comeuppance", [[passarsela]] "to fare (well, badly)",
	--              [[rifarsela]] "to take revenge", [[sbirbarsela]] "to slide by (in life)",
	--              [[farsela]]/[[intendersela]] "to have a secret affair or relationship with",
	--              [[farsela addosso]] "to shit oneself", [[prendersela]] "to take offense at; to blame",
	--              [[prendersela comoda]] "to take one's time", [[sbrigarsela]] "to finish up; to get out of (a difficult situation)",
	--              [[tirarsela]] "to lord it over", [[godersela]] "to enjoy", [[vedersela]] "to see (something) through",
	--              [[vedersela brutta]] "to have a hard time with; to be in a bad situation",
	--              [[aversela]] "to pick on (someone)", [[battersela]] "to run away, to sneak away",
	--              [[darsela a gambe]] "to run away", [[fumarsela]] "to sneak away",
	--              [[giocarsela]] "to behave (a certain way); to strategize; to play"
	--   * se + ne: [[andarsene]] "to take leave", [[approfittarsene]] "to take advantage of",
	--              [[fottersene]]/[[strafottersene]] "to not give a fuck",
	--              [[fregarsene]]/[[strafregarsene]] "to not give a damn",
	--              [[guardarsene]] "to beware; to think twice", [[impiparsene]] "to not give a damn",
	--              [[morirsene]] "to fade away; to die a lingering death", [[ridersene]] "to laugh at; to not give a damn",
	--              [[ritornarsene]] "to return to", [[sbattersene]]/[[strabattersene]] "to not give a damn",
	--              [[infischiarsene]] "to not give a damn", [[stropicciarsene]] "to not give a damn",
	--              [[sbarazzarsene]] "to get rid of, to bump off", [[andarsene in acqua]] "to be diluted; to decay",
	--              [[nutrirsene]] "to feed oneself", [[curarsene]] "to take care of",
	--              [[intendersene]] "to be an expert (in)", [[tornarsene]] "to return, to go back",
	--              [[starsene]] "to stay", [[farsene]] "to matter; to (not) consider; to use",
	--              [[farsene una ragione]] "to resign; to give up; to come to terms with; to settle (a dispute)",
	--              [[riuscirsene]] "to repeat (something annoying)", [[venirsene]] "to arrive slowly; to leave"
	--   * ci + si: [[trovarcisi]] "to find oneself in a happy situation",
	--              [[vedercisi]] "to imagine oneself (in a situation)", [[sentircisi]] "to feel at ease"
	--   * vi + si: [[recarvisi]] "to go there"
	--
	local ret = {}
	local finite_pref, finite_pref_ho
	local clitic_to_finite = {ce = "ce", ve = "ve", se = "me"}
	local verb, clitic, clitic2 = rmatch(lemma, "^(.-)([cvs]e)(l[ae])$")
	local linked_verb
	if verb then
		linked_verb = "[[" .. verb .. "]][[" .. clitic .. "]][[" .. clitic2 .. "]]"
		finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[" .. clitic2 .. "]] "
		finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[l']]"
		is_pronominal = true
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cvs]e)ne$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[" .. clitic .. "]][[ne]]"
			finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[ne]] "
			finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[n']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)si$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[" .. clitic .. "]][[si]]"
			finite_pref = "[[mi]] [[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[mi]] [[v']]"
			else
				finite_pref_ho = "[[mi]] [[ci]] "
			end
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[v']]"
			else
				finite_pref_ho = "[[ci]] "
			end
			is_pronominal = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)si$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[mi]]"
			finite_pref = "[[mi]] "
			finite_pref_ho = "[[m']]"
			-- not pronominal
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)ne$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[ne]]"
			finite_pref = "[[ne]] "
			finite_pref_ho = "[[n']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)(l[ae])$")
		if verb then
			linked_verb = "[[" .. verb .. "]][[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			finite_pref_ho = "[[l']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb = lemma
		linked_verb = "[[" .. verb .. "]]"
		finite_pref = ""
		finite_pref_ho = ""
		-- not pronominal
	end

	local stem, conj_vowel = rmatch(verb, "^(.-)([aeiour])re?$")
	if not stem then
		error("Unrecognized verb '" .. verb .. "', doesn't end in -are, -ere, -ire, -rre, -ar, -er, -ir, -or or -ur")
	end
	if rfind(verb, "r$") then
		if rfind(verb, "[ou]r$") or base.trarre then
			verb = verb .. "re"
		else
			verb = verb .. "e"
		end
	end
	ret.verb = verb
	ret.linked_verb = linked_verb
	ret.finite_pref = finite_pref
	ret.finite_pref_ho = finite_pref_ho
	ret.is_pronominal = is_pronominal


	if not rfind(conj_vowel, "^[aei]$") then
		-- Can't generate defaults for verbs in -rre
		return ret
	end

	if base.third then
		ret.pres = conj_vowel == "a" and stem .. "a" or stem .. "e"
	else
		ret.pres = stem .. "o"
	end
	if conj_vowel == "i" then
		ret.isc_pres = stem .. "ìsco"
	end
	if conj_vowel == "a" then
		ret.past = stem .. (base.third and "ò" or "ài")
	elseif conj_vowel == "e" then
		ret.past = {stem .. (base.third and "é" or "éi"), stem .. (base.third and "ètte" or "ètti")}
	else
		ret.past = stem .. (base.third and "ì" or "ìi")
	end
	if conj_vowel == "a" then
		ret.pp = stem .. "àto"
	elseif conj_vowel == "e" then
		ret.pp = rfind(stem, "[cg]$") and stem .. "iùto" or stem .. "ùto"
	else
		ret.pp = stem .. "ìto"
	end

	return ret
end

-- Add links around words. If multiword_only, do it only in multiword forms.
local function add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end

local function strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end

local function check_not_null(base, form)
	if form == nil then
		error("Default forms cannot be derived from '" .. base.lemma .. "'")
	end
end

local function pres_special_case(base, form, def)
	if form == "+" then
		check_not_null(base, def.pres)
		return def.pres
	elseif form == "+isc" then
		check_not_null(base, def.isc_pres)
		return def.isc_pres
	elseif form == "-" then
		return form
	elseif rfind(form, "^" .. AV .. "[+-]?$") then
		check_not_null(base, def.pres)
		local pres, final_vowel = rmatch(def.pres, "^(.*)([oae])$")
		if not pres then
			error("Internal error: Default present '" .. def.pres .. "' doesn't end in -o, -a or -e")
		end
		local TEMP_QU = u(0xFFF1)
		local TEMP_U_IN_AU = u(0xFFF2)
		pres = rsub(pres, "qu", TEMP_QU)
		pres = rsub(pres, "au(" .. NV .. "*" .. V .. NV .. "*)$", "a" .. TEMP_U_IN_AU .. "%1")
		local before, v1, between, v2, after = rmatch(pres, "^(.*)(" .. V .. ")(" .. NV .. "*)(" .. V .. ")(" .. NV .. "*)$")
		if not before then
			before, v1 = "", ""
			between, v2, after = rmatch(pres, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
		end
		if not between then
			error("No vowel in default present '" .. def.pres .. "' to match")
		end
		if v1 == v2 then
			local form_vowel, first_second = rmatch(form, "^(.)([+-])$")
			if not form_vowel then
				error("Last two stem vowels of default present '" .. def.pres ..
					"'are the same; you must specify + (second vowel) or - (first vowel) after the vowel spec '" ..
					form .. "'")
			end
			local raw_form_vowel = usub(unfd(form_vowel), 1, 1)
			if raw_form_vowel ~= v1 then
				error("Vowel spec '" .. form .. "' doesn't match vowel of default present '" .. def.pres .. "'")
			end
			if first_second == "-" then
				form = before .. form_vowel .. between .. v2 .. after
			else
				form = before .. v1 .. between .. form_vowel .. after
			end
		else
			if rfind(form, "[+-]$") then
				error("Last two stem vowels of default present '" .. def.pres ..
					"'are different; specify just an accented vowel, without a following + or -: '" .. form .. "'")
			end
			local raw_form_vowel = usub(unfd(form), 1, 1)
			if raw_form_vowel == v1 then
				form = before .. form .. between .. v2 .. after
			elseif raw_form_vowel == v2 then
				form = before .. v1 .. between .. form .. after
			elseif before == "" then
				error("Vowel spec '" .. form .. "' doesn't match vowel of default present '" .. def.pres .. "'")
			else
				error("Vowel spec '" .. form .. "' doesn't match either of the last two vowels of default present '" .. def.pres .. "'")
			end
		end
		form = rsub(form, TEMP_QU, "qu")
		form = rsub(form, TEMP_U_IN_AU, "u")
		return form .. final_vowel
	elseif not base.third and not rfind(form, "[oò]$") then
		error("Present first-person singular form '" .. form .. "' should end in -o")
	elseif base.third and not rfind(form, "[aàeè]") then
		error("Present third-person singular form '" .. form .. "' should end in -a or -e")
	else
		return form
	end
end

local function past_special_case(base, form, def)
	if form == "+" then
		check_not_null(base, def.past)
		return def.past
	elseif form ~= "-" and not base.third and not rfind(form, "i$") then
		error("Past historic form '" .. form .. "' should end in -i")
	else
		return form
	end
end

local function pp_special_case(base, form, def)
	if form == "+" then
		check_not_null(base, def.pp)
		return def.pp
	elseif form ~= "-" and not rfind(form, "o$") then
		error("Past participle form '" .. form .. "' should end in -o")
	else
		return form
	end
end

local irreg_forms = { "imperf", "fut", "sub", "impsub", "imp" }

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		local pagename = args.pagename or PAGENAME

		if args[1] then
			local arg1 = args[1]
			if not arg1:find("<.*>") then
				arg1 = "<" .. arg1 .. ">"
			end

			local iut = require("Module:inflection utilities")

			-- (1) Parse the indicator specs inside of angle brackets.

			local function parse_indicator_spec(angle_bracket_spec)
				local base = {forms = {}, irreg_forms = {}}
				local function parse_err(msg)
					error(msg .. ": " .. angle_bracket_spec)
				end

				local function fetch_qualifiers(separated_group)
					local qualifiers
					for j = 2, #separated_group - 1, 2 do
						if separated_group[j + 1] ~= "" then
							parse_err("Extraneous text after bracketed qualifiers: '" .. table.concat(separated_group) .. "'")
						end
						if not qualifiers then
							qualifiers = {}
						end
						table.insert(qualifiers, separated_group[j])
					end
					return qualifiers
				end

				local function fetch_specs(comma_separated_group)
					local specs = {}

					local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
					for _, colon_separated_group in ipairs(colon_separated_groups) do
						local form = colon_separated_group[1]
						-- Below, we check for a nil form when replacing with the default, so replace
						-- blank forms (requesting the default) with nil.
						if form == "" then
							form = nil
						end
						table.insert(specs, {form = form, qualifiers = fetch_qualifiers(colon_separated_group)})
					end
					return specs
				end

				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)

				local segments = iut.parse_balanced_segment_run(inside, "[", "]")
				local dot_separated_groups = iut.split_alternating_runs(segments, "%s*%.%s*")
				for i, dot_separated_group in ipairs(dot_separated_groups) do
					local first_element = dot_separated_group[1]
					if first_element == "only3s" or first_element == "only3sp" or first_element == "trarre" then
						if #dot_separated_groups[1] > 1 then
							parse_err("No footnotes allowed with '" .. first_element .. "' spec")
						end
						base[first_element] = true
					else
						local saw_irreg = false
						for _, irreg_form in ipairs(irreg_forms) do
							local first_element_minus_prefix = rmatch(first_element, "^" .. irreg_form .. ":(.*)$")
							if first_element_minus_prefix then
								dot_separated_group[1] = first_element_minus_prefix
								base.irreg_forms[irreg_form] = fetch_specs(dot_separated_group)
								saw_irreg = true
								break
							end
						end
						if not saw_irreg then
							local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*[,/]%s*", "preserve splitchar")
							if #comma_separated_groups == 1 or strip_spaces(comma_separated_groups[2][1]) ~= "/" then
								parse_err("Principal parts must be in the form AUX/PRES or AUX/PRES,PAST,PP: '" ..
									table.concat(dot_separated_group) .. "'")
							end

							-- Parse auxiliaries
							local colon_separated_groups = iut.split_alternating_runs(comma_separated_groups[1], ":")
							for _, colon_separated_group in ipairs(colon_separated_groups) do
								local aux = colon_separated_group[1]
								if aux == "a" then
									aux = "avere"
								elseif aux == "e" then
									aux = "essere"
								else
									parse_err("Unrecognized auxiliary '" .. aux ..
										"', should be 'a' (for [[avere]]) or 'e' for ([[essere]])")
								end
								if base.aux then
									for _, existing_aux in ipairs(base.aux) do
										if existing_aux.form == aux then
											parse_err("Auxiliary '" .. aux .. "' specified twice")
										end
									end
								else
									base.aux = {}
								end
								table.insert(base.aux, {form = aux, footnotes = fetch_qualifiers(colon_separated_group)})
							end

							-- Parse present
							base.pres = fetch_specs(comma_separated_groups[3])

							-- Parse past historic
							if #comma_separated_groups > 3 then
								if strip_spaces(comma_separated_groups[4][1]) ~= "," then
									parse_err("Use a comma not slash to separate present from past historic")
								end
								base.past = fetch_specs(comma_separated_groups[5])
							end

							-- Parse past participle
							if #comma_separated_groups > 5 then
								if strip_spaces(comma_separated_groups[6][1]) ~= "," then
									parse_err("Use a comma not slash to separate past historic from past participle")
								end
								base.pp = fetch_specs(comma_separated_groups[7])
							end

							if #comma_separated_groups > 7 then
								parse_err("Extraneous text after past participle")
							end
						end
					end
				end
				return base
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
				allow_blank_lemma = true,
			}
			local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)

			-- (2) Add links to all before and after text.

			if not args.noautolinktext then
				alternant_multiword_spec.post_text = add_links(alternant_multiword_spec.post_text)
				for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
					alternant_or_word_spec.before_text = add_links(alternant_or_word_spec.before_text)
					if alternant_or_word_spec.alternants then
						for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
							multiword_spec.post_text = add_links(multiword_spec.post_text)
							for _, word_spec in ipairs(multiword_spec.word_specs) do
								word_spec.before_text = add_links(word_spec.before_text)
							end
						end
					end
				end
			end

			-- (3) Remove any links from the lemma, but remember the original form
			--     so we can use it below in the 'lemma_linked' form.

			iut.map_word_specs(alternant_multiword_spec, function(base)
				if base.lemma == "" then
					base.lemma = pagename
				end
				if not args.noautolinkverb then
					-- Add links to the lemma so the user doesn't specifically need to, since we preserve
					-- links in multiword lemmas and include links in non-lemma forms rather than allowing
					-- the entire form to be a link.
					base.orig_lemma = add_links(base.lemma)
				else
					base.orig_lemma = base.lemma
				end
				base.lemma = m_links.remove_links(base.lemma)

				-- Handling of only3s and only3p.
				if base.only3s and base.only3sp then
					error("'only3s' and 'only3sp' cannot both be specified")
				end
				base.third = base.only3s or base.only3sp
				if alternant_multiword_spec.third == nil then
					alternant_multiword_spec.third = base.third
				elseif alternant_multiword_spec.third ~= base.third then
					error("If some alternants specify 'only3s' or 'only3sp', all must")
				end
			end)

			-- (4) Conjugate the verbs according to the indicator specs parsed above.

			local sing_accel = alternant_multiword_spec.third and "3|s" or "1|s"
			local sing_label = alternant_multiword_spec.third and "third-person singular" or "first-person singular"
			local all_verb_slots = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_accel .. "|pres|ind",
				past_form = sing_accel .. "|phis",
				pp_form = "m|s|past|part",
				imperf_form = sing_accel .. "|impf|ind",
				fut_form = sing_accel .. "|fut|ind",
				sub_form = sing_accel .. "|pres|sub",
				impsub_form = sing_accel .. "|impf|sub",
				imp_form = "2|s|imp",
				-- aux should not be here. It doesn't have an accelerator and isn't "conjugated" normally.
			}
			local all_verb_slot_labels = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_label .. " present",
				past_form = sing_label .. " past historic",
				pp_form = "past participle",
				imperf_form = sing_label .. " imperfect",
				fut_form = sing_label .. " future",
				sub_form = sing_label .. " present subjunctive",
				impsub_form = sing_label .. " imperfect subjunctive",
				imp_form = "second-person singular imperative",
				aux = "auxiliary",
			}

			local function conjugate_verb(base)
				local this_def_forms = base_default_verb_forms(base, base.lemma)
				base.is_pronominal = this_def_forms.is_pronominal
				if base.is_pronominal then
					alternant_multiword_spec.is_pronominal = true
				end

				local function process_specs(slot, specs, is_part, special_case)
					specs = specs or {{form = "+"}}
					for _, spec in ipairs(specs) do
						local decorated_form = spec.form
						local preserve_monosyllabic_accent, form, syntactic_gemination =
							rmatch(decorated_form, "^(%*?)(.-)(%**)$")
						local forms = special_case(base, form, this_def_forms)
						if type(forms) ~= "table" then
							forms = {forms}
						end
						for _, form in ipairs(forms) do
							local qualifiers = spec.qualifiers
							-- If the form is -, insert it directly, unlinked; we handle this specially
							-- below, turning it into special labels like "no past participle".
							if form ~= "-" then
								local unaccented_form
								if rfind(form, "^.*" .. V .. ".*" .. AV .. "$") then
									-- final accented vowel with preceding vowel; keep accent
									unaccented_form = form
								elseif rfind(form, AV .. "$") and preserve_monosyllabic_accent == "*" then
									unaccented_form = form
									qualifiers = iut.combine_footnotes(qualifiers, {"[with written accent]"})
								else
									unaccented_form = rsub(form, AV, function(v) return usub(unfd(v), 1, 1) end)
								end
								if syntactic_gemination == "*" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with following syntactic gemination]"})
								elseif syntactic_gemination == "**" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with optional following syntactic gemination]"})
								elseif syntactic_gemination ~= "" then
									error("Decorated form '" .. decorated_form .. "' has too many asterisks after it, use '*' for syntactic gemination and '**' for optional syntactic gemination")
								end
								form = "[[" .. unaccented_form .. "|" .. form .. "]]"
								if not is_part then
									if unaccented_form == "ho" then
										form = this_def_forms.finite_pref_ho .. form
									else
										form = this_def_forms.finite_pref .. form
									end
								end
							end
							iut.insert_form(base.forms, slot, {form = form, footnotes = qualifiers})
						end
					end
				end

				process_specs("pres_form", base.pres, nil, pres_special_case)
				process_specs("past_form", base.past, nil, past_special_case)
				process_specs("pp_form", base.pp, "is part", pp_special_case)

				local function irreg_special_case(base, form, def)
					return form
				end

				for _, irreg_form in ipairs(irreg_forms) do
					if base.irreg_forms[irreg_form] then
						process_specs(irreg_form .. "_form", base.irreg_forms[irreg_form], irreg_form == "imp",
							irreg_special_case)
					end
				end

				iut.insert_form(base.forms, "lemma", {form = base.lemma})
				-- Add linked version of lemma for use in head=. We write this in a general fashion in case
				-- there are multiple lemma forms (which isn't possible currently at this level, although it's
				-- possible overall using the ((...,...)) notation).
				iut.insert_forms(base.forms, "lemma_linked", iut.map_forms(base.forms.lemma, function(form)
					if form == base.lemma then
						return this_def_forms.linked_verb
					else
						return form
					end
				end))
			end

			local inflect_props = {
				slot_table = all_verb_slots,
				inflect_word_spec = conjugate_verb,
				-- We add links around the generated verbal forms rather than allow the entire multiword
				-- expression to be a link, so ensure that user-specified links get included as well.
				include_user_specified_links = true,
			}
			iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

			-- Set the overall auxiliary or auxiliaries. We can't do this using the normal inflection
			-- code as it will produce e.g. '[[avere]] e [[avere]]' for conjoined verbs.
			iut.map_word_specs(alternant_multiword_spec, function(base)
				iut.insert_forms(alternant_multiword_spec.forms, "aux", base.aux)
			end)

			-- (5) Fetch the forms and put the conjugated lemmas in data.heads if not explicitly given.

			local function strip_brackets(qualifiers)
				if not qualifiers then
					return nil
				end
				local stripped_qualifiers = {}
				for _, qualifier in ipairs(qualifiers) do
					local stripped_qualifier = qualifier:match("^%[(.*)%]$")
					if not stripped_qualifier then
						error("Internal error: Qualifier should be surrounded by brackets at this stage: " .. qualifier)
					end
					table.insert(stripped_qualifiers, stripped_qualifier)
				end
				return stripped_qualifiers
			end

			local function do_verb_form(slot, label)
				local forms = alternant_multiword_spec.forms[slot]
				if not forms or #forms == 0 then
					-- This will happen with unspecified irregular forms.
					return
				end

				local accel_form = all_verb_slots[slot]
				local label = all_verb_slot_labels[slot]
				local retval
				if forms[1].form == "-" then
					retval = {label = "no " .. label}
				else
					retval = {label = label, accel = accel_form and {form = accel_form} or nil}
					for _, form in ipairs(forms) do
						local qualifiers = strip_brackets(form.footnotes)
						table.insert(retval, {term = form.form, qualifiers = qualifiers})
					end
				end
				table.insert(data.inflections, retval)
			end

			if alternant_multiword_spec.is_pronominal then
				table.insert(data.inflections, {label = glossary_link("pronominal")})
			end
			
			do_verb_form("pres_form")
			do_verb_form("past_form")
			do_verb_form("pp_form")
			for _, irreg_form in ipairs(irreg_forms) do
				do_verb_form(irreg_form .. "_form")
			end
			do_verb_form("aux")

			-- Add categories.
			for _, form in ipairs(alternant_multiword_spec.forms.aux) do
				table.insert(data.categories, "Italian verbs taking " .. form.form .. " as auxiliary")
			end
			if alternant_multiword_spec.is_pronominal then
				table.insert(data.categories, "Italian pronominal verbs")
			end

			-- Use the "linked" form of the lemma as the head if no head= explicitly given.
			if #data.heads == 0 then
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.lemma_linked) do
					local lemma = lemma_obj.form
					table.insert(data.heads, lemma)
				end
			end
		end
	end
}

return export
