local export = {}

local put_module = "Module:parse utilities"
local labels_module = "Module:labels"
local references_module = "Module:references"
local rsplit = mw.text.split

local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q", "qq"}
-- Do m_table.listToSet(param_mods) inline, maybe saving memory?
local param_mod_set = {}
for _, param_mod in ipairs(param_mods) do
	param_mod_set[param_mod] = true
end


local function track(page)
	return require("Module:debug/track")("nyms/" .. page)
end


local function wrap_span(text, lang, sc)
	return '<span class="' .. sc .. '" lang="' .. lang .. '">' .. text .. '</span>'
end


function export.parse_qualifier(arg, parse_err)
	return {arg}
end

function export.parse_accent_qualifier(arg, parse_err)
	-- FIXME: Pass `parse_err` to split_labels_on_comma().
	return require(labels_module).split_labels_on_comma(arg)
end

function export.parse_reference(arg, parse_err)
	return require(references_module).parse_references(arg, parse_err)
end

local function split_on_comma(term)
	if term:find(",%s") then
		return require(put_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end


local pron_qualifier_param_mods = {
	q = {
		separate_no_index = true,
		convert = parse_qualifier,
	},
	qq = {
		separate_no_index = true,
		convert = parse_qualifier,
	},
	a = {
		separate_no_index = true,
		convert = parse_accent_qualifier,
	},
	aa = {
		separate_no_index = true,
		convert = parse_accent_qualifier,
	},
	ref = {
		convert = parse_references,
	},
}

function export.augment_params_with_modifiers(params, param_mods)
	local list_with_holes = { list = true, allow_holes = true }
	-- Add parameters for each term modifier.
	for param_mod, param_mod_spec in pairs(param_mods) do
		local param_key = param_mod_spec.param_key or param_mod
		if not param_mod_spec.extra_specs then
			params[param_key] = list_with_holes
		else
			local param_spec = mw.clone(list_with_holes)
			for k, v in pairs(param_mod_spec.extra_specs) do
				param_spec[k] = v
			end
			if param_mod_spec.require_index then
				param_spec.require_index = true
			end
			params[param_key] = param_spec
		end
	end
end

-- Convert a raw lb= param (or nil) to a list of label info objects of the format described in get_label_info() in
-- [[Module:labels]]). Unrecognized labels will end up with an unchanged display form. Return nil if nil passed in.
local function get_label_list_info(raw_lb, lang)
	if not raw_lb then
		return nil
	end
	return require(labels_module).get_label_list_info(split_on_comma(raw_lb), lang, "nocat")
end

local function parse_term_with_modifiers(data, paramname, val, lang_cache)
	local function generate_obj(term, parse_err)
		local obj = {}
		if data.parse_lang_prefix and term:find(":") then
			local actual_term, termlangs = require(parse_utilities_module).parse_term_with_lang {
				term = term,
				parse_err = parse_err,
				paramname = paramname,
				allow_bad = data.allow_bad_lang_prefix,
				lang_cache = lang_cache,
			}
			obj.term = actual_term
			obj.termlangs = termlangs
			obj.lang = termlangs and termlangs[1] or lang
		else
			obj.term = term
			obj.lang = lang
		end
		obj.sc = sc
		return obj
	end

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{m|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if val:find("<") and not val:find("^[^<]*<[a-z]*[^a-z:]") then
		return require(parse_utilities_module).parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = param_mods,
			generate_obj = generate_obj,
		})
	else
		return generate_obj(val)
	end
end

function export.process_list_arguments(data)
	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(data.args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	local items = {}
	local ind = 0
	local lang_cache = {}
	if data.lang then
		lang_cache[data.lang:getCode()] = data.lang
	end
	for i = 1, maxmaxindex do
		local item = args[data.termarg][i]
		if item ~= ";" then
			ind = ind + 1
			local termobj = parse_term_with_modifiers(data.termarg + i - 1, item, lang_cache)
			else
				termlang = lang
				termlangcode = nil
			end
			local termobj = {
				joiner = i > 1 and (args[2][i - 1] == ";" and "; " or ", ") or "",
				q = args["q"][syn],
				qq = args["qq"][syn],
				lb = args["partlb"][syn],
				term = {
					lang = termlang, term = item, id = args["id"][syn],
					sc = args["sc"][syn] and require("Module:scripts").getByCode(args["sc"][syn], "sc" .. syn) or nil,
					alt = args["alt"][syn], tr = args["tr"][syn], ts = args["ts"][syn],
					gloss = args["t"][syn], lit = args["lit"][syn], pos = args["pos"][syn],
					genders = args["g"][syn] and rsplit(args["g"][syn], ",") or nil,
				},
			}
		
			-- Check for new-style argument, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>,
			-- <i ...>, <br/> or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar.
			-- Basically, all tags of the sort we parse here should consist of a less-than sign, plus letters,
			-- plus a colon, e.g. <tr:...>, so if we see a tag on the outer level that isn't in this format,
			-- we don't try to parse it. The restriction to the outer level is to allow generated HTML inside
			-- of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
			if item and item:find("<") and not item:find("^[^<]*<[a-z]*[^a-z:]") then
				if not put then
					put = require(put_module)
				end
				local run = put.parse_balanced_segment_run(item, "<", ">")
				local function parse_err(msg)
					error(msg .. ": " .. (i + 1) .. "=" .. table.concat(run))
				end
				termobj.term.term = run[1]

				for j = 2, #run - 1, 2 do
					if run[j + 1] ~= "" then
						parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
					end
					local modtext = run[j]:match("^<(.*)>$")
					if not modtext then
						parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
					end
					local prefix, arg = modtext:match("^([a-z]+):(.*)$")
					if not prefix then
						parse_err("Modifier " .. run[j] .. " lacks a prefix, should begin with one of '" ..
							table.concat(param_mods, ":', '") .. ":'")
					end
					if param_mod_set[prefix] or prefix == "lb" then
						local obj_to_set
						if prefix == "q" or prefix == "qq" or prefix == "lb" then
							obj_to_set = termobj
						else
							obj_to_set = termobj.term
						end
						if prefix == "t" then
							prefix = "gloss"
						elseif prefix == "g" then
							prefix = "genders"
							arg = rsplit(arg, ",")
						elseif prefix == "sc" then
							arg = require("Module:scripts").getByCode(arg, "" .. (i + 1) .. ":sc")
						end
						if obj_to_set[prefix] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
						end
						obj_to_set[prefix] = arg
					elseif prefix == "tag" then
						-- FIXME: Remove support for <tag:...> in favor of <lb:...>
						error("Use <lb:...> instead of <tag:...>")
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[j])
					end
				end
			elseif item and item:find(",", 1, true) then
				-- FIXME: Why is this here and when is it used?
				use_semicolon = true
			end
			-- If a separate language code was given for the term, display the language name as a right qualifier.
			-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is 'zh'
			-- and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms, which
			-- are often added to the list of English and other-language terms.
			if termlangcode and termlangcode ~= langcode and termlangcode ~= "mul" then
				termobj.qq = {termlang:getCanonicalName(), termobj.qq}
			end
		table.insert(items, termobj)
		end
	end

	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.joiner = "; "
			end
		end
	end

	for i, item in ipairs(items) do
		local label_text = ""
		if item.lb then
			local labels = get_label_list_info(item.lb, lang)
			if labels then
				label_text = " " .. require(labels_module).format_processed_labels {
					labels = labels, lang = lang, open = "[", close = "]"
				}
			end
		end
		items[i] = item.joiner .. (item.q and require("Module:qualifier").format_qualifier(item.q) .. " " or "") .. m_links.full_link(item.term)
			.. (item.qq and " " .. require("Module:qualifier").format_qualifier(item.qq) or "") .. label_text
	end

	local labels = get_label_list_info(args.lb, lang)
	local label_postq = labels and " &mdash; " .. require(labels_module).format_processed_labels {
		labels = labels, lang = lang 
	} or ""
	return "<span class=\"nyms " .. nym_type_class .. "\"><span class=\"defdate\">" .. 
		mw.getContentLanguage():ucfirst(nym_type) .. ((#items > 1 or thesaurus ~= "") and "s" or "") ..
		":</span> " .. table.concat(items) .. label_postq .. thesaurus .. "</span>"
end


return export
