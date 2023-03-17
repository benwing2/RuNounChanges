-- This module contains code for Italian headword templates.
-- Templates covered are:
-- * {{it-noun}}, {{it-proper noun}};
-- * {{it-verb}};
-- * {{it-adj}}, {{it-adj-comp}}, {{it-adj-sup}};
-- * {{it-det}};
-- * {{it-art}};
-- * {{it-pron-adj}};
-- * {{it-pp}};
-- * {{it-presp}};
-- * {{it-card-noun}}, {{it-card-adj}}, {{it-card-inv}};
-- * {{it-adv}};
-- * {{it-pos}};
-- * {{it-suffix form}}.
-- See [[Module:it-verb]] for Italian conjugation templates.
-- See [[Module:it-conj]] for an older Italian conjugation module that is still widely used but will be going away.

local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local m_links = require("Module:links")
local m_table = require("Module:table")
local headword_module = "Module:headword"
local romut_module = "Module:romance utilities"
local it_verb_module = "Module:it-verb"
local put_module = "Module:parse utilities"
local strut_module = "Module:string utilities"
local com = require("Module:it-common")
local lang = require("Module:languages").getByCode("it")
local langname = lang:getCanonicalName()
-- Assigned to `require("Module:parse utilities")` as necessary.
local put

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
local unfc = mw.ustring.toNFC

local GR = u(0x0300)
local V = "[aeiou]"
local NV = "[^aeiou]"
local AV = "[àèéìòóù]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug/track")("it-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local function check_all_missing(forms, plpos, tracking_categories)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form then
			local title = mw.title.new(form)
			if title and not title.exists then
				table.insert(tracking_categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
		end
	end
end

local no_split_apostrophe_words = {
	["c'è"] = true,
	["c'era"] = true,
	["c'erano"] = true,
}


-- The main entry point.
function export.show(frame)
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
		["id"] = {},
		["sort"] = {},
		["apoc"] = {type = "boolean"},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local user_specified_heads = args.head
	local heads = user_specified_heads
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		end
	else
		local romut = require(romut_module)
		local auto_linked_head = romut.add_links_to_multiword_term(pagename, args.splithyph,
			no_split_apostrophe_words)
		if #heads == 0 then
			heads = {auto_linked_head}
		else
			for i, head in ipairs(heads) do
				if head:find("^~") then
					head = romut.apply_link_modifiers(auto_linked_head, usub(head, 2))
					heads[i] = head
				end
				if head == auto_linked_head then
					track("redundant-head")
				end
			end
		end
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	local is_suffix = false
	if pagename:find("^%-") and poscat ~= "suffix forms" then
		is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	local tracking_categories = {}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame, is_suffix)
	end

	if args.apoc then
		-- Apocopated form of a term; do this after calling pos_functions[], because the function might modify
		-- data.pos_category.
		local pos = data.pos_category
		if not pos:find(" forms") then
			-- Apocopated forms are non-lemma forms.
			local singular_poscat = require("Module:string utilities").singularize(pos)
			data.pos_category = singular_poscat .. " forms"
		end
		-- If this is a suffix, insert label 'apocopated' after 'FOO-forming suffix', otherwise insert at the beginning.
		table.insert(data.inflections, is_suffix and 2 or 1, {label = glossary_link("apocopated")})
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require(headword_module).full_headword(data)
		.. (#tracking_categories > 0 and require("Module:utilities").format_categories(tracking_categories, lang, args.sort, nil, force_cat) or "")
end

local function fetch_qualifiers(qual, existing)
	if not qual then
		return existing
	end
	if not existing then
		return {qual}
	end
	local retval = {}
	for _, e in ipairs(existing) do
		table.insert(retval, e)
	end
	table.insert(retval, qual)
	return retval
end

local function process_terms_with_qualifiers(terms, quals)
	local infls = {}
	for i, term in ipairs(terms) do
		table.insert(infls, {term = term, qualifiers = fetch_qualifiers(quals[i])})
	end
	return infls
end

local function replace_hash_with_lemma(term, lemma)
	-- If there is a % sign in the lemma, we have to replace it with %% so it doesn't get interpreted as a capture replace
	-- expression.
	lemma = lemma:gsub("%%", "%%%%")
	-- Assign to a variable to discard second return value.
	term = term:gsub("#", lemma)
	return term
end


local deriv_params = {
	{"dim", glossary_link("diminutive")},
	{"aug", glossary_link("augmentative")},
	{"pej", glossary_link("pejorative")},
	{"derog", glossary_link("derogatory")},
	{"end", glossary_link("endearing")},
	{"dim_aug", glossary_link("diminutive") .. "-" .. glossary_link("augmentative")},
	{"dim_pej", glossary_link("diminutive") .. "-" .. glossary_link("pejorative")},
	{"dim_derog", glossary_link("diminutive") .. "-" .. glossary_link("derogatory")},
	{"dim_end", glossary_link("diminutive") .. "-" .. glossary_link("endearing")},
	{"aug_pej", glossary_link("augmentative") .. "-" .. glossary_link("pejorative")},
	{"aug_derog", glossary_link("augmentative") .. "-" .. glossary_link("derogatory")},
	{"aug_end", glossary_link("augmentative") .. "-" .. glossary_link("endearing")},
	{"end_derog", glossary_link("endearing") .. "-" .. glossary_link("derogatory")},
}


local function insert_deriv_params(params)
	local list_spec = {list = true}
	for _, deriv_param in ipairs(deriv_params) do
		local param, desc = unpack(deriv_param)
		params[param] = list_spec
	end
end


local param_mods = {
	t = {
		-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "gloss",
	},
	gloss = {},
	-- no 'tr' or 'ts', doesn't make sense for Italian
	g = {
		-- We need to store the <g:...> inline modifier into the "genders" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "genders",
		convert = function(arg, parse_err)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {},
	qq = {},
	lit = {},
	pos = {},
	-- no 'sc', doesn't make sense for Italian
}


local function parse_term_with_modifiers(paramname, val)
	local function generate_obj(term)
		local decomp = com.decompose(term)
		local lemma = com.remove_non_final_accents(decomp)
		if lemma ~= decomp then
			term = com.compose("[[" .. lemma .. "|" .. decomp .. "]]")
		end
		return {term = term}
	end

	local retval
	local splitchars = "[/;,]"
	-- Check for inline modifier, e.g. מרים<tr:Miryem>.
	if val:find("<") then
		if not put then
			put = require(put_module)
		end
		retval = put.parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = param_mods,
			generate_obj = generate_obj,
			splitchar = splitchars,
			preserve_splitchar = true,
		})
	else
		local split
        if val:find(",%s") then
			if not put then
				put = require(put_module)
			end
            split = put.split_escaping(val, splitchars, true, put.escape_comma_whitespace,
				put.unescape_comma_whitespace)
        else
            split = require(strut_module).capturing_split(val, "(" .. splitchars .. ")")
        end
		retval = {}
        for j = 1, #split, 2 do
			local obj = generate_obj(split[j])
			if j > 1 then
				obj.separator = split[j - 1]
			end
			table.insert(retval, obj)
        end
	end

	for _, obj in ipairs(retval) do
		if obj.separator == ";" then
			obj.separator = "; "
		elseif obj.separator == "," then
			obj.separator = nil
		end
	end

	return retval
end


local function insert_deriv_inflections(data, args, plpos)
	for _, deriv_param in ipairs(deriv_params) do
		local param, desc = unpack(deriv_param)
		if #args[param] > 0 then
			local inflection = {label = desc}
			for i, term in ipairs(args[param]) do
				local parsed_terms = parse_term_with_modifiers(param, term)
				for _, parsed_term in ipairs(parsed_terms) do
					table.insert(inflection, parsed_term)
				end
			end
			-- These will typically be missing for now so it doesn't help to do this.
			-- check_all_missing(inflection, plpos, tracking_categories)
			table.insert(data.inflections, inflection)
		end
	end
end


-----------------------------------------------------------------------------------------
--                                          Nouns                                      --
-----------------------------------------------------------------------------------------

local allowed_genders = m_table.listToSet(
	{"m", "f", "mf", "mfbysense", "n", "m-p", "f-p", "mf-p", "mfbysense-p", "n-p", "?", "?-p"}
)


local function process_genders(data, genders, g_qual)
	for i, g in ipairs(genders) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
end


local function do_noun(args, data, tracking_categories, pos, is_suffix, is_proper)
	local is_plurale_tantum = false
	local has_singular = false
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	data.genders = {}
	local saw_m = false
	local saw_f = false
	local gender_for_default_plural = args[1][1]
	process_genders(data, args[1], args.g_qual)
	-- Check for specific genders and pluralia tantum.
	for _, g in ipairs(args[1]) do
		if g:find("-p$") then
			is_plurale_tantum = true
		else
			has_singular = true
			if g == "m" or g == "mf" or g == "mfbysense" then
				saw_m = true
			end
			if g == "f" or g == "mf" or g == "mfbysense" then
				saw_f = true
			end
		end
	end
	if saw_m and saw_f then
		gender_for_default_plural = "mf"
	end

	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified

	local function insert_inflection(list, term, accel, qualifiers, genders, no_inv)
		if genders then
			for _, g in ipairs(genders) do
				if g == "m" and not saw_m or g == "f" and not saw_f then
					table.insert(data.categories, langname .. " " .. plpos .. " that change gender in the plural")
				end
			end
		end
					
		local infl = {qualifiers = qualifiers, accel = accel, genders = genders}
		if term == lemma and not no_inv then
			infl.label = glossary_link("invariable")
		else
			infl.term = term
		end
		infl.term_for_further_inflection = term
		table.insert(list, infl)
	end

	-- Plural
	local plurals = {}
	local args_mpl = args.mpl
	local args_fpl = args.fpl
	local args_pl = args[2]

	if is_plurale_tantum and not has_singular then
		if #args_pl > 0 then
			error("Can't specify plurals of plurale tantum " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	elseif args.apoc then
		-- apocopated noun
		if #args_pl > 0 then
			error("Can't specify plurals of apocopated " .. pos)
		end
	else
		if is_plurale_tantum then
			-- both singular and plural
			table.insert(data.inflections, {label = "sometimes " .. glossary_link("plural only") .. ", in variation"})
		end
		-- If no plurals, use the default plural unless mpl= or fpl= explicitly given.
		if #args_pl == 0 and #args_mpl == 0 and #args_fpl == 0 and not is_proper then
			args_pl = {"+"}
		end
		-- If only ~ given (countable and uncountable), add the default plural after it.
		if #args_pl == 1 and args_pl[1] == "~" then
			args_pl = {"~", "+"}
		end
		-- Gather plurals, handling requests for default plurals
		for i, pl in ipairs(args_pl) do
			local function insert_pl(term)
				if term == lemma and i == 1 then
					-- Invariable
					-- If plural forms were given explicitly, then show "usually"
					if #args_pl > 1 then
						table.insert(data.inflections, {label = "usually " .. glossary_link("invariable")})
					else
						table.insert(data.inflections, {label = glossary_link("invariable")})
					end
					table.insert(data.categories, langname .. " indeclinable " .. plpos)
				else
					insert_inflection(plurals, term, nil, fetch_qualifiers(args.pl_qual[i]),
						args.pl_g[i] and rsplit(args.pl_g[i], "%s*,%s*") or nil)
				end
				table.insert(data.categories, langname .. " countable " .. plpos)
			end
			local function make_gendered_plural(form, gender, special)
				if gender == "mf" then
					local default_mpl = com.make_plural(lemma, "m", special)
					local default_fpl = com.make_plural(lemma, "f", special)
					if default_mpl then
						if default_mpl == default_fpl then
							insert_pl(default_mpl)
						else
							if #args_mpl > 0 or #args_fpl > 0 then
								error("Can't specify gendered plural spec '" .. (special or "+") .. "' along with gender=" .. gender
									.. " and also specify mpl= or fpl=")
							end
							args_mpl = {default_mpl}
							args_fpl = {default_fpl}
						end
					end
				else
					local pl = com.make_plural(lemma, gender, special)
					if pl then
						insert_pl(pl)
					end
				end
			end

			if pl == "cap*" or pl == "cap*+" then
				make_gendered_plural(lemma, gender_for_default_plural, pl)
			elseif pl == "+" then
				make_gendered_plural(lemma, gender_for_default_plural)
			elseif pl:find("^%+") then
				pl = require(romut_module).get_special_indicator(pl)
				make_gendered_plural(lemma, gender_for_default_plural, pl)
			elseif pl == "?" or pl == "!" then
				if i > 1 or #args_pl > 1 then
					error("Can't specify ? or ! with other plurals")
				end
				if pl == "?" then
					-- Plural is unknown
					table.insert(data.inflections, {label = "plural unknown or uncertain"})
					table.insert(data.categories, langname .. " " .. plpos .. " with unknown or uncertain plurals")
				else
					-- Plural is not attested
					table.insert(data.inflections, {label = "plural not attested"})
					table.insert(data.categories, langname .. " " .. plpos .. " with unattested plurals")
				end
			elseif pl == "-" then
				if i > 1 then
					error("Plural specifier - must be first")
				end
				-- Uncountable noun; may occasionally have a plural
				table.insert(data.categories, langname .. " uncountable " .. plpos)

				-- If plural forms were given explicitly, then show "usually"
				if #args_pl > 1 then
					table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
					table.insert(data.categories, langname .. " countable " .. plpos)
				else
					table.insert(data.inflections, {label = glossary_link("uncountable")})
				end
			elseif pl == "~" then
				if i > 1 then
					error("Plural specifier ~ must be first")
				end
				-- Countable and uncountable noun; will have a plural
				table.insert(data.categories, langname .. " countable " .. plpos)
				table.insert(data.categories, langname .. " uncountable " .. plpos)
				table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
			else
				insert_pl(replace_hash_with_lemma(pl, lemma))
			end
		end
	end
	
	if #plurals > 1 then
		table.insert(data.categories, langname .. " " .. plpos .. " with multiple plurals")
	end

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(mfs, qualifiers, gender, inflect, default_plurals)
		local retval = {}
		for i, mf in ipairs(mfs) do
			local function insert_infl(list, term, accel, existing_qualifiers)
				insert_inflection(list, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), nil, "no inv")
			end
			if mf == "+" then
				-- Generate default feminine.
				mf = inflect(lemma)
			else
				mf = replace_hash_with_lemma(mf, lemma)
			end
			local special = require(romut_module).get_special_indicator(mf)
			if special then
				mf = inflect(lemma, special)
			end
			insert_infl(retval, mf)
			local mfpl = com.make_plural(mf, gender, special)
			if mfpl then
				-- Add an accelerator for each masculine/feminine plural whose lemma
				-- is the corresponding singular, so that the accelerated entry
				-- that is generated has a definition that looks like
				-- # {{plural of|es|MFSING}}
				insert_infl(default_plurals, mfpl, {form = "p", lemma = mf})
			end
		end
		return retval
	end

	local default_feminine_plurals = {}
	local feminine_plurals = {}
	local feminines = handle_mf(args.f, args.f_qual, "f", com.make_feminine, default_feminine_plurals)
	local default_masculine_plurals = {}
	local masculine_plurals = {}
	local masculines = handle_mf(args.m, args.m_qual, "m", com.make_masculine, default_masculine_plurals)

	local function handle_mf_plural(mfpl, qualifiers, gender, default_plurals, singulars)
		local new_mfpls = {}
		for i, mfpl in ipairs(mfpl) do
			local function insert_infl(term, accel, existing_qualifiers, no_inv)
				insert_inflection(new_mfpls, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), nil, no_inv)
			end
			local accel
			if #mfpl == #singulars then
				-- If same number of overriding masculine/feminine plurals as singulars,
				-- assume each plural goes with the corresponding singular
				-- and use each corresponding singular as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|it|SINGULAR}} as the
				-- definition.
				accel = {form = "p", lemma = singulars[i].term}
			else
				accel = nil
			end
			if mfpl == "+" then
				if #default_plurals > 0 then
					for _, defpl in ipairs(default_plurals) do
						-- defpl is a table
						-- don't use "invariable" because the plural is not with respect to the lemma but
						-- with respect to the masc/fem singular
						insert_infl(defpl.term_for_further_inflection, defpl.accel, defpl.qualifiers, "no inv")
					end
				else
					-- mf is a table
					local default_mfpl = com.make_plural(lemma, gender)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			elseif mfpl == "cap*" or mfpl == "cap*+" or mfpl:find("^%+") then
				if mfpl:find("^%+") then
					mfpl = require(romut_module).get_special_indicator(mfpl)
				end
				if #singulars > 0 then
					for _, mf in ipairs(singulars) do
						-- mf is a table
						local default_mfpl = com.make_plural(mf.term_for_further_inflection, gender, mfpl)
						if default_mfpl then
							-- don't use "invariable" because the plural is not with respect to the lemma but
							-- with respect to the masc/fem singular
							insert_infl(default_mfpl, accel, mf.qualifiers, "no inv")
						end
					end
				else
					local default_mfpl = com.make_plural(lemma, gender, mfpl)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			else
				mfpl = replace_hash_with_lemma(mfpl, lemma)
				-- don't use "invariable" if masc/fem singular present because the plural is not with respect to
				-- the lemma but with respect to the masc/fem singular
				insert_infl(mfpl, accel, nil, #singulars > 0)
			end
		end
		return new_mfpls
	end

	-- FIXME: We should generate feminine plurals by default from feminine singulars given, and vice-versa.
	-- To do that, eliminate the distinction between `default_feminine_plurals` and `feminine_plurals`,
	-- as in [[Module:es-headword]].
	if #args_fpl > 0 then
		-- Set feminine plurals.
		feminine_plurals = handle_mf_plural(args_fpl, args.fpl_qual, "f", default_feminine_plurals, feminines)
	end

	if #args_mpl > 0 then
		-- Set masculine plurals.
		masculine_plurals = handle_mf_plural(args_mpl, args.mpl_qual, "m", default_masculine_plurals, masculines)
	end

	check_all_missing(plurals, plpos, tracking_categories)
	check_all_missing(feminines, plpos, tracking_categories)
	check_all_missing(feminine_plurals, plpos, tracking_categories)
	check_all_missing(masculines, plpos, tracking_categories)
	check_all_missing(masculine_plurals, plpos, tracking_categories)

	local function redundant_plural(pl)
		for _, p in ipairs(plurals) do
			if p.term_for_further_inflection == pl.term_for_further_inflection then
				return true
			end
		end
		return false
	end

	for _, mpl in ipairs(masculine_plurals) do
		if redundant_plural(mpl) then
			track("noun-redundant-mpl")
		end
	end

	for _, fpl in ipairs(feminine_plurals) do
		if redundant_plural(fpl) then
			track("noun-redundant-fpl")
		end
	end

	if #plurals > 0 then
		plurals.label = "plural"
		plurals.accel = {form = "p"}
		table.insert(data.inflections, plurals)
	end

	if #masculines > 0 then
		masculines.label = "masculine"
		table.insert(data.inflections, masculines)
	end

	if #masculine_plurals > 0 then
		masculine_plurals.label = "masculine plural"
		table.insert(data.inflections, masculine_plurals)
	end

	if #feminines > 0 then
		feminines.label = "feminine"
		feminines.accel = {form = "f"}
		table.insert(data.inflections, feminines)
	end

	if #feminine_plurals > 0 then
		feminine_plurals.label = "feminine plural"
		table.insert(data.inflections, feminine_plurals)
	end

	insert_deriv_inflections(data, args, plpos)

	-- Maybe add category 'Italian nouns with irregular gender' (or similar)
	local irreg_gender_lemma = rsub(lemma, " .*", "") -- only look at first word
	if (irreg_gender_lemma:find("o$") and (gender_for_default_plural == "f" or gender_for_default_plural == "mf"
		or gender_for_default_plural == "mfbysense")) or
		(irreg_gender_lemma:find("a$") and (gender_for_default_plural == "m" or gender_for_default_plural == "mf"
		or gender_for_default_plural == "mfbysense")) then
		table.insert(data.categories, langname .. " " .. plpos .. " with irregular gender")
	end
end

local function get_noun_params(nountype)
	local params = {
		[1] = {list = "g", required = nountype ~= "proper", default = "?"},
		[2] = {list = "pl"},
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["pl_g"] = {list = "pl=_g", allow_holes = true},
		["m"] = {list = true},
		["m_qual"] = {list = "m=_qual", allow_holes = true},
		["f"] = {list = true},
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["mpl"] = {list = true},
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["fpl"] = {list = true},
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
	}
	insert_deriv_params(params)
	return params
end

pos_functions["nouns"] = {
	params = get_noun_params("base"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "noun", is_suffix)
	end,
}

pos_functions["proper nouns"] = {
	params = get_noun_params("proper"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "proper noun", is_suffix, "is proper noun")
	end,
}

pos_functions["cardinal nouns"] = {
	params = get_noun_params("base"),
	func = function(args, data, tracking_categories)
		do_noun(args, data, tracking_categories, "numeral")
		data.pos_category = "numerals"
		table.insert(data.categories, 1, langname .. " cardinal numbers")
	end,
}


-----------------------------------------------------------------------------------------
--                                       Adjectives                                    --
-----------------------------------------------------------------------------------------

local function do_adjective(args, data, tracking_categories, pos, is_suffix, is_superlative)
	local feminines = {}
	local masculine_plurals = {}
	local feminine_plurals = {}
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	if not is_suffix then
		data.pos_category = plpos
	end

	if args.sp then
		local romut = require(romut_module)
		if not romut.allowed_special_indicators[args.sp] then
			local indicators = {}
			for indic, _ in pairs(romut.allowed_special_indicators) do
				table.insert(indicators, "'" .. indic .. "'")
			end
			table.sort(indicators)
			error("Special inflection indicator beginning can only be " ..
				m_table.serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
		end
	end

	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified

	local function insert_inflection(forms, label, accel)
		if #forms > 0 then
			if forms[1].term == "-" then
				table.insert(data.inflections, {label = "no " .. label})
			else
				forms.label = label
				forms.accel = {form = accel}
				table.insert(data.inflections, forms)
			end
		end
	end

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = glossary_link("invariable")})
		table.insert(data.categories, langname .. " indeclinable " .. plpos)
	end
	if args.noforms then
		-- [[bello]] and any others too complicated to describe in headword
		table.insert(data.inflections, {label = "see below for inflection"})
	end
	if args.inv or args.apoc or args.noforms then
		if args.sp or #args.f > 0 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
			error("Can't specify inflections with an invariable or apocopated adjective or with noforms=")
		end
	elseif args.fonly then
		-- feminine-only
		if #args.f > 0 then
			error("Can't specify explicit feminines with feminine-only adjective")
		end
		if #args.pl > 0 then
			error("Can't specify explicit plurals with feminine-only adjective, use fpl=")
		end
		if #args.mpl > 0 then
			error("Can't specify explicit masculine plurals with feminine-only adjective")
		end
		local argsfpl = args.fpl
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end
		for i, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				local defpl = com.make_plural(lemma, "f", args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				fpl = defpl
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
			end
			table.insert(feminine_plurals, {term = fpl, qualifiers = fetch_qualifiers(args.fpl_qual[i])})
		end

		check_all_missing(feminine_plurals, plpos, tracking_categories)

		table.insert(data.inflections, {label = "feminine-only"})
		insert_inflection(feminine_plurals, "feminine plural", "f|p")
	else
		-- Gather feminines.
		local argsf = args.f
		if #argsf == 0 then
			argsf = {"+"}
		end
		for i, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = com.make_feminine(lemma, args.sp)
			else
				f = replace_hash_with_lemma(f, lemma)
			end
			table.insert(feminines, {term = f, qualifiers = fetch_qualifiers(args.f_qual[i])})
		end

		local argsmpl = args.mpl
		local argsmpl_qual = args.mpl_qual
		local argsfpl = args.fpl
		local argsfpl_qual = args.fpl_qual
		if #args.pl > 0 then
			if #argsmpl > 0 or #argsfpl > 0 then
				error("Can't specify both pl= and mpl=/fpl=")
			end
			argsmpl = args.pl
			argsmpl_qual = args.pl_qual
			argsfpl = args.pl
			argsfpl_qual = args.pl_qual
		end
		if #argsmpl == 0 then
			argsmpl = {"+"}
		end
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end

		for i, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpl = com.make_plural(lemma, "m", args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				mpl = defpl
			else
				mpl = replace_hash_with_lemma(mpl, lemma)
			end
			table.insert(masculine_plurals, {term = mpl, qualifiers = fetch_qualifiers(argsmpl_qual[i])})
		end

		for i, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural; f is a table.
					local defpl = com.make_plural(f.term, "f", args.sp)
					if not defpl then
						error("Unable to generate default plural of '" .. f.term .. "'")
					end
					table.insert(feminine_plurals, {term = defpl, qualifiers = fetch_qualifiers(argsfpl_qual[i], f.qualifiers)})
				end
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
				table.insert(feminine_plurals, {term = fpl, qualifiers = fetch_qualifiers(argsfpl_qual[i])})
			end
		end

		check_all_missing(feminines, plpos, tracking_categories)
		check_all_missing(masculine_plurals, plpos, tracking_categories)
		check_all_missing(feminine_plurals, plpos, tracking_categories)

		-- Make sure there are feminines given and not same as lemma.
		if not (#feminines == 1 and feminines[1].term == lemma and not feminines[1].qualifiers) then
			insert_inflection(feminines, "feminine", "f|s")
		end

		if #masculine_plurals > 0 and #feminine_plurals > 0 and
			m_table.deepEquals(masculine_plurals, feminine_plurals) then
			insert_inflection(masculine_plurals, "plural", "p")
		else
			insert_inflection(masculine_plurals, "masculine plural", "m|p")
			insert_inflection(feminine_plurals, "feminine plural", "f|p")
		end
	end

	if args.comp and #args.comp > 0 then
		local comps = process_terms_with_qualifiers(args.comp, args.comp_qual)
		check_all_missing(comps, plpos, tracking_categories)
		comps.label = "comparative"
		table.insert(data.inflections, comps)
	end

	if args.sup and #args.sup > 0 then
		local sups = process_terms_with_qualifiers(args.sup, args.sup_qual)
		check_all_missing(sups, plpos, tracking_categories)
		sups.label = "superlative"
		table.insert(data.inflections, sups)
	end

	insert_deriv_inflections(data, args, plpos)

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative adjectives")
	end
end

local function get_adjective_params(adjtype)
	local params = {
		["inv"] = {type = "boolean"}, --invariable
		["noforms"] = {type = "boolean"}, --too complicated to list forms except in a table
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["pl"] = {list = true}, --plural override(s)
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
	}
	if adjtype == "base" or adjtype == "part" or adjtype == "det" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
		params["fonly"] = {type = "boolean"} -- feminine only
	end
	if adjtype == "sup" then
		params["irreg"] = {type = "boolean"}
	end
	insert_deriv_params(params)
	return params
end

pos_functions["adjectives"] = {
	params = get_adjective_params("base"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix)
	end,
}

pos_functions["comparative adjectives"] = {
	params = get_adjective_params("comp"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix)
	end,
}

pos_functions["superlative adjectives"] = {
	params = get_adjective_params("sup"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix, "is superlative")
	end,
}

pos_functions["cardinal adjectives"] = {
	params = get_adjective_params("card"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "numeral", is_suffix)
		table.insert(data.categories, 1, langname .. " cardinal numbers")
	end,
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "participle", is_suffix)
		data.pos_category = "past participles"
	end,
}

pos_functions["present participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "participle", is_suffix)
		data.pos_category = "present participles"
	end,
}

pos_functions["determiners"] = {
	params = get_adjective_params("det"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "determiner", is_suffix)
	end,
}

pos_functions["articles"] = {
	params = get_adjective_params("det"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "article", is_suffix)
	end,
}

pos_functions["adjective-like pronouns"] = {
	params = get_adjective_params("pron"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "pronoun", is_suffix)
	end,
}

pos_functions["cardinal invariable"] = {
	params = {},
	func = function(args, data, tracking_categories)
		data.pos_category = "numerals"
		table.insert(data.categories, langname .. " cardinal numbers")
		table.insert(data.categories, langname .. " indeclinable numerals")
		table.insert(data.inflections, {label = glossary_link("invariable")})
	end,
}


-----------------------------------------------------------------------------------------
--                                        Adverbs                                      --
-----------------------------------------------------------------------------------------

local function do_adverb(args, data, tracking_categories, pos, is_suffix)
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	if not is_suffix then
		data.pos_category = plpos
	end

	if args.comp and #args.comp > 0 then
		local comps = process_terms_with_qualifiers(args.comp, args.comp_qual)
		check_all_missing(comps, "adverbs", tracking_categories)
		comps.label = "comparative"
		table.insert(data.inflections, comps)
	end

	if args.sup and #args.sup > 0 then
		local sups = process_terms_with_qualifiers(args.sup, args.sup_qual)
		check_all_missing(sups, "adverbs", tracking_categories)
		sups.label = "superlative"
		table.insert(data.inflections, sups)
	end
end

local function get_adverb_params(advtype)
	local params = {}
	if advtype == "base" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
	end
	return params
end

pos_functions["adverbs"] = {
	params = get_adverb_params("base"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}

pos_functions["comparative adverbs"] = {
	params = get_adverb_params("comp"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}

pos_functions["superlative adverbs"] = {
	params = get_adverb_params("sup"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}


-----------------------------------------------------------------------------------------
--                                         Verbs                                       --
-----------------------------------------------------------------------------------------

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		if args[1] then
			local preses, prets, parts
			local def_forms

			local alternant_multiword_spec = require(it_verb_module).do_generate_forms(args, "from headword", data.heads[1])

			local function expand_footnotes_and_references(footnotes)
				if not footnotes then
					return nil
				end
				local quals, refs
				for _, qualifier in ipairs(footnotes) do
					local this_footnote, this_refs =
						require("Module:inflection utilities").expand_footnote_or_references(qualifier, "return raw")
					if this_refs then
						if not refs then
							refs = this_refs
						else
							for _, ref in ipairs(this_refs) do
								table.insert(refs, ref)
							end
						end
					else
						if not quals then
							quals = {this_footnote}
						else
							table.insert(quals, this_footnote)
						end
					end
				end
				return quals, refs
			end

			local function do_verb_form(slot, label, rowslot, rowlabel)
				local forms = alternant_multiword_spec.forms[slot]
				local retval
				if alternant_multiword_spec.rowprops.all_defective[rowslot] then
					if not alternant_multiword_spec.rowprops.defective[rowslot] then
						-- No forms, but none expected; don't display anything
						return
					end
					retval = {label = "no " .. rowlabel}
				elseif not forms then
					retval = {label = "no " .. label}
				elseif alternant_multiword_spec.rowprops.all_unknown[rowslot] then
					retval = {label = "unknown " .. rowlabel}
				elseif forms[1].form == "?" then
					retval = {label = "unknown " .. label}
				else
					-- Disable accelerators for now because we don't want the added accents going into the headwords.
					-- FIXME: We now have support in [[Module:accel]] to specify the target explicitly; we can use this
					-- so we can add the accelerators back with a param to avoid the accents.
					local accel_form = nil -- all_verb_slots[slot]
					retval = {label = label, accel = accel_form and {form = accel_form} or nil}
					local prev_footnotes = nil
					-- If the footnotes for this form are the same as the footnotes for the preceding form or
					-- contain the preceding footnotes, replace the footnotes that are the same with "ditto".
					-- This avoids repetition on pages like [[succedere]] where the form ''succedétti'' has a long
					-- footnote which gets repeated in the traditional form ''succedètti'' (which also has the
					-- footnote "[traditional]").
					for _, form in ipairs(forms) do
						local quals, refs = expand_footnotes_and_references(form.footnotes)
						local quals_with_ditto = quals
						if quals and prev_footnotes then
							local quals_contains_previous = true
							for _, qual in ipairs(prev_footnotes) do
								if not m_table.contains(quals, qual) then
									quals_contains_previous = false
									break
								end
							end
							if quals_contains_previous then
								local inserted_ditto = false
								quals_with_ditto = {}
								for _, qual in ipairs(quals) do
									if m_table.contains(prev_footnotes, qual) then
										if not inserted_ditto then
											table.insert(quals_with_ditto, "ditto")
											inserted_ditto = true
										end
									else
										table.insert(quals_with_ditto, qual)
									end
								end
							end
						end
						prev_footnotes = quals
						table.insert(retval, {term = form.form, qualifiers = quals_with_ditto, refs = refs})
					end
				end

				table.insert(data.inflections, retval)
			end

			if alternant_multiword_spec.props.is_pronominal then
				table.insert(data.inflections, {label = glossary_link("pronominal")})
			end
			if alternant_multiword_spec.props.impers then
				table.insert(data.inflections, {label = glossary_link("impersonal")})
			end
			if alternant_multiword_spec.props.thirdonly then
				table.insert(data.inflections, {label = "third-person only"})
			end
			
			local thirdonly = alternant_multiword_spec.props.impers or alternant_multiword_spec.props.thirdonly
			local sing_label = thirdonly and "third-person singular" or "first-person singular"
			for _, rowspec in ipairs {
				{"pres", "present", true},
				{"phis", "past historic", true},
				{"pp", "past participle", true},
				{"imperf", "imperfect"},
				{"fut", "future"},
				{"sub", "subjunctive"},
				{"impsub", "imperfect subjunctive"},
			} do
				local rowslot, desc, always_show = unpack(rowspec)
				local slot = rowslot .. (thirdonly and "3s" or "1s")
				local must_show = alternant_multiword_spec.is_irreg[slot]
				if always_show then
					must_show = true
				elseif rowslot == "imperf" and alternant_multiword_spec.props.has_explicit_stem_spec then
					-- If there is an explicit stem spec, make sure it gets displayed; the imperfect is a good way of
					-- showing this.
					must_show = true
				elseif not alternant_multiword_spec.forms[slot] then
					-- If the principal part is unexpectedly missing, make sure we show this.
					must_show = true
				elseif alternant_multiword_spec.forms[slot][1].form == "?" then
					-- If the principal part is unknown, make sure we show this.
					must_show = true
				end
				if must_show then
					if rowslot == "pp" then
						do_verb_form(rowslot, desc, rowslot, desc)
					else
						do_verb_form(slot, sing_label .. " " .. desc, rowslot, desc)
					end
				end
			end
			-- Also do the imperative, but not for third-only verbs, which are always missing the imperative.
			if not thirdonly and (alternant_multiword_spec.is_irreg.imp2s
				or not alternant_multiword_spec.forms.imp2s) then
				do_verb_form("imp2s", "second-person singular imperative", "imp", "imperative")
			end
			-- If there is a past participle but no auxiliary (e.g. [[malfare]]), explicitly add "no auxiliary". In
			-- cases where there's no past participle and no auxiliary (e.g. [[irrompere]]), we don't do this as we
			-- already get "no past participle" displayed. Don't display an auxiliary in any case if the lemma
			-- consists entirely of reflexive verbs (for which the auxiliary is always [[essere]]).
			if alternant_multiword_spec.props.is_non_reflexive and (
				alternant_multiword_spec.forms.aux or alternant_multiword_spec.forms.pp 
			) then
				do_verb_form("aux", "auxiliary", "aux", "auxiliary")
			end

			-- Add categories.
			for _, cat in ipairs(alternant_multiword_spec.categories) do
				table.insert(data.categories, cat)
			end

			-- If the user didn't explicitly specify head=, or specified exactly one head (not 2+) and we were able to
			-- incorporate any links in that head into the 1= specification, use the infinitive generated by
			-- [[Module:it-verb]] it in place of the user-specified or auto-generated head so that we get accents marked
			-- on the verb(s). Don't do this if the user gave multiple heads or gave a head with a multiword-linked
			-- verbal expression such as '[[dare esca]] [[al]] [[fuoco]]'.
			if #data.user_specified_heads == 0 or (
				#data.user_specified_heads == 1 and alternant_multiword_spec.incorporated_headword_head_into_lemma
			) then
				data.heads = {}
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.inf) do
					-- FIXME, can't yet specify qualifiers or references for heads
					table.insert(data.heads, lemma_obj.form)
					-- local quals, refs = expand_footnotes_and_references(lemma_obj.footnotes)
					-- table.insert(data.heads, {term = lemma_obj.form, qualifiers = quals, refs = refs})
				end
			end
		end
	end
}


-----------------------------------------------------------------------------------------
--                                      Suffix forms                                   --
-----------------------------------------------------------------------------------------

pos_functions["suffix forms"] = {
	params = {
		[1] = {required = true, list = true},
		["g"] = {list = true},
		["g_qual"] = {list = "g=_qual", allow_holes = true},
	},
	func = function(args, data, tracking_categories, frame)
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		local suffix_type = {}
		for _, typ in ipairs(args[1]) do
			table.insert(suffix_type, typ .. "-forming suffix")
		end
		table.insert(data.inflections, {label = "non-lemma form of " .. m_table.serialCommaJoin(suffix_type, {conj = "or"})})
	end,
}


-----------------------------------------------------------------------------------------
--                                Arbitrary parts of speech                            --
-----------------------------------------------------------------------------------------

pos_functions["arbitrary part of speech"] = {
	params = {
		[1] = {required = true},
		["g"] = {list = true},
		["g_qual"] = {list = "g=_qual", allow_holes = true},
	},
	func = function(args, data, tracking_categories, frame, is_suffix)
		if is_suffix then
			error("Can't use [[Template:it-pos]] with suffixes")
		end
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		local plpos = require("Module:string utilities").pluralize(args[1])
		data.pos_category = plpos
	end,
}

return export
