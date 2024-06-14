local export = {}

local labels_module = "Module:labels"
local languages_module = "Module:languages"
local parameters_module = "Module:parameters"
local parse_utilities_module = "Module:parse utilities"
local references_module = "Module:references"
local scripts_module = "Module:scripts"
local string_utilities_module = "Module:string utilities"

local function track(page, track_module)
	return require("Module:debug/track")((track_module or "parameter utilities") .. "/" .. page)
end

function export.parse_qualifier(arg, parse_err)
	return {arg}
end

function export.parse_labels(arg, parse_err)
	-- FIXME: Pass `parse_err` to split_labels_on_comma().
	return require(labels_module).split_labels_on_comma(arg)
end

function export.parse_references(arg, parse_err)
	return require(references_module).parse_references(arg, parse_err)
end

function export.parse_script(arg, parse_err)
	return require(scripts_module).getByCode(arg, parse_err)
end

function export.parse_lang(arg, parse_err, allow_etym, allow_family)
	return require(languages_module).getByCode(arg, parse_err, allow_etym, allow_family)
end

local function rsplit(text, pattern)
	return require(string_utilities_module).split(text, pattern)
end

function export.split_on_comma_allow_whitespace(arg, parse_err)
	if arg:find(",") then
		return rsplit(arg, "%s*,%s*")
	else
		return {arg}
	end
end

function export.parse_genders = export.split_on_comma_allow_whitespace

--[==[ intro:
The `param_mods` structure holds per-param modifiers, which can be specified either as separate parameters (e.g.
{{para|t2}}, {{para|pos3}}) or as inline modifiers (`<t:...>`, `<pos:...>`, etc). The key is the name of the parameter
(e.g. {"t"}, {"pos"}) and the value is a table with optional elements as follows:
* `extra_specs`: A table of extra key-value pairs to add to the spec used for parsing the parameter when specified as a
  separate parameter (e.g. { {type = "boolean"}} for a Boolean parameter, or { {alias_of = "t"}} for the {{para|gloss}}
  parameter, which is aliased to {{para|t}}, on top of the default, which is { {list = true, allow_holes = true}}.
* `convert`: A function to convert the raw argument into the form stored in a term object. This function takes two
  parameters: (1) `arg` (the raw argument); (2) `parse_err` (a function used to throw an error in case of a parse
  error).
* `item_dest`: The name of the key used when storing the parameter's value into the processed term object. Normally the
  same as the parameter's name. Different in the case e.g. of {"t"}, where we store the gloss in {"gloss"}, and {"g"},
  where we store the genders in {"genders"} (in both cases for compatibility with [[Module:links]]).
* `param_key`: The name of the key used when storing the parameter's value into the `args` object returned by
  [[Module:parameters]]. Normally the same as the parameter's name. May be different e.g. in the case of the separate
  no-index pattern (where e.g. {{para|sc}} is distinct from {{para|sc1}}), where e.g. the key {"sc"} would be used to
  hold the value of {{para|sc}} and a key like {"listsc"} would be used to hold the value of {{para|sc1}}, {{para|sc2}},
  etc.; but prefer using `separate_no_index = true` in place of this.
* `require_index`: Same as the `require_index` property in [[Module:parameters]].
* `separate_no_index`: Same as the `separate_no_index` property in [[Module:parameters]].
* `type`: Like the `type` property in [[Module:parameters]].
]==]

function export.augment_param_mods_with_pron_qualifiers(param_mods, qtypes)
	qtypes = qtypes or {"q", "a", "ref"}
	for _, qtype in ipairs(qtypes) do
		if type(qtype) == "string" then
			qtype = {qtype}
		end
		local param = qtype.param
		local function get_separate_no_index(default)
			local retval = qtype.separate_no_index
			if retval == nil then
				return default
			else
				return retval
			end
		end

		if param == "q" then
			local qspec = {
				separate_no_index = get_separate_no_index(true),
				convert = export.parse_qualifier,
			}
			pron_qualifier_param_mods.q = qspec
			pron_qualifier_param_mods.qq = qspec
		elseif param == "a" or param == "l" then
			local laspec = {
				separate_no_index = get_separate_no_index(true),
				convert = export.parse_labels,
			}
			if qtype == "a" then
				pron_qualifier_param_mods.a = laspec
				pron_qualifier_param_mods.aa = laspec
			else
				pron_qualifier_param_mods.l = laspec
				pron_qualifier_param_mods.ll = laspec
			end
		elseif param == "ref" then
			pron_qualifier_param_mods.ref = {
				item_dest = "refs",
				separate_no_index = get_separate_no_index(false),
				convert = export.parse_references,
			}
		else
			error(("Internal error: Unrecognized qualifier type '%s'"):format(qtype))
		end
	end
end

function export.augment_params_with_modifiers(params, param_mods)
	local list_with_holes = { list = true, allow_holes = true }
	-- Add parameters for each term modifier.
	for param_mod, param_mod_spec in pairs(param_mods) do
		local param_key = param_mod_spec.param_key or param_mod
		local has_extra_specs = false
		for k, _ in pairs(param_mod_spec) do
			if k ~= "param_key" and k ~= "item_dest" and k ~= "convert" then
				has_extra_specs = true
				break
			end
		end
		if not has_extra_specs then
			params[param_key] = list_with_holes
		else
			local param_spec = mw.clone(list_with_holes)
			for k, v in pairs(param_mod_spec) do
				if k ~= "param_key" and k ~= "item_dest" and k ~= "convert" then
					param_spec[k] = v
				end
			end
			params[param_key] = param_spec
		end
	end
end

function export.process_list_arguments(data)
	-- Find the maximum index among any of the list parameters.
	local term_args = data.args[data.termarg]
	-- As a special case, the term args might not have a `maxindex` field because they might have
	-- been declared with `disallow_holes = true`, so fall back to the actual length of the list.
	local maxmaxindex = term_args.maxindex or #term_args
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
	local use_semicolon = false
	local term_dest = data.term_dest or "term"

	local termno = 0
	for i = 1, maxmaxindex do
		local term = term_args[i]
		if term ~= ";" then
			termno = termno + 1

			-- Compute whether any of the separate indexed params exist for this index.
			local any_param_at_index = term ~= nil
			if not any_param_at_index then
				for k, v in pairs(data.args) do
					-- Look for named list parameters. We check:
					-- (1) key is a string (excludes the term param, which is a number);
					-- (2) value is a table, i.e. a list;
					-- (3) v.maxindex is set (i.e. allow_holes was used);
					-- (4) the value has an entry at index `termno` (the current logical index).
					if type(k) == "string" and type(v) == "table" and v.maxindex and v[termno] then
						any_param_at_index = true
						break
					end
				end
			end

			-- If any of the params used for formatting this term is present, create a term and add it to the list.
			if not any_param_at_index then
				track("skipped-term", data.track_module)
			else
				if not term then
					track("missing-term", data.track_module)
				end
				-- Initialize the `termobj` object passed to full_link() in [[Module:links]].
				local termobj = {
					separator = i > 1 and (term_args[i - 1] == ";" and "; " or ", ") or "",
					termno = termno,
				}

				-- Parse all the term-specific parameters and store in `termobj`.
				for param_mod, param_mod_spec in pairs(data.param_mods) do
					local dest = param_mod_spec.item_dest or param_mod
					local param_key = param_mod_spec.param_key or param_mod
					local arg = data.args[param_key] and data.args[param_key][termno]
					if arg then
						if param_mod_spec.convert or param_mod_spec.type or param_mod_spec.set or
							param_mod_spec.sublist then
							-- WARNING: Here we embed some knowledge of convert_val() in [[Module:parameters]],
							-- specifically that if none of `type`, `set` and `sublist` are set, the conversion is an
							-- identity operation and can be skipped. If this becomes problematic, remove the
							-- optimization.
							local function parse_err(msg, stack_frames_to_ignore)
								error(("%s: %s%s=%s"):format(
									msg, param_mod, (termno > 1 or param_mod_spec.require_index or
										param_mod_spec.separate_no_index) and termno or "", arg
								), stack_frames_to_ignore
								)
							end
							if param_mod_spec.convert then
								arg = param_mod_spec.convert(arg, parse_err)
							else
								arg = require(parameters_module).convert_val(arg, parse_err, param_mod_spec)
							end
						end
						termobj[dest] = arg
					end
				end

				local function generate_obj(term, parse_err)
					if data.parse_lang_prefix and term:find(":") then
						local actual_term, termlangs = require(parse_utilities_module).parse_term_with_lang {
							term = term,
							parse_err = parse_err,
							paramname = paramname,
							allow_bad = data.allow_bad_lang_prefix,
							allow_multiple = data.allow_multiple_lang_prefixes,
							lang_cache = lang_cache,
						}
						termobj[term_dest] = actual_term ~= "" and actual_term or nil
						if data.allow_multiple_lang_prefixes then
							termobj.termlangs = termlangs
							termobj.lang = termlangs and termlangs[1] or nil
						else
							termobj.termlang = termlangs
							termobj.lang = termlangs
						end
					else
						termobj[term_dest] = term ~= "" and term or nil
					end
					return termobj
				end

				-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude top-level HTML entry with <span ...>,
				-- <br/> or similar in it, often caused by wrapping an argument in {{m|...}} or similar.
				if term and term:find("<") and not require(parse_utilities_module).term_contains_top_level_html(term) then
					require(parse_utilities_module).parse_inline_modifiers(term, {
						-- Add 1 because first term index starts at 2.
						paramname = data.termarg + i - 1,
						param_mods = data.param_mods,
						generate_obj = generate_obj,
					})
				elseif term then
					generate_obj(term)
				end
				-- Set these after parsing inline modifiers, not in generate_obj(), otherwise we'll get an error in
				-- parse_inline_modifiers() if we try to use <lang:...> or <sc:...> as inline modifiers.
				termobj.lang = termobj.lang or data.lang
				termobj.sc = termobj.sc or data.sc

				-- If the displayed term (from .term/etc. or .alt) has an embedded comma, use a semicolon to join the terms.
				local term_text = termobj[term_dest] or termobj.alt
				if not use_semicolon and term_text then
					if term_text:find(",", 1, true) then
						use_semicolon = true
					end
				end

				-- If the to-be-linked term is the same as the pagename, maybe display it unlinked.
				if data.disallow_self_link and data.lang and data.pagename and termobj[term_dest] and
					(data.lang:makeEntryName(termobj[term_dest])) == data.pagename then
					track("term-is-pagename", data.track_module)
					termobj.alt = termobj.alt or termobj[term_dest]
					termobj[term_dest] = nil
				end

				table.insert(items, termobj)
			end
		end
	end

	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.separator = "; "
			end
		end
	end

	return items
end


return export
