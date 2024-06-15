local export = {}

local dump = mw.dumpObject
local labels_module = "Module:labels"
local languages_module = "Module:languages"
local parameters_module = "Module:User:Benwing2/parameters"
local parse_utilities_module = "Module:User:Benwing2/parse utilities"
local references_module = "Module:references"
local scripts_module = "Module:scripts"

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

--[==[ intro:
The purpose of this module is to facilitate implementation of a template that takes a list of items with associated
properties, which can be specified either through separate parameters (e.g. {{para|t2}}, {{para|pos3}}) or inline
modifiers (`<t:...>`, `<pos:...>`, etc.). Some examples of templates that work this way are {{tl|alter}}/{{tl|alt}};
{{tl|synonyms}}/{{tl|syn}}, {{tl|antonyms}}}/{{tl|ant}}, and other "nyms" templates; {{tl|col}}, {{tl|col2}},
{{tl|col3}}, {{tl|col4}} and other columns templates; {{tl|descendants}}/{{tl|desc}}; {{tl|affixusex}}/{{tl|afex}};
{{tl|IPA}}; {{tl|homophones}}; {{tl|rhymes}}; and several others. Not all of them currently use this module, but they
should all eventually be converted to do so. This module can be thought of as a combination of [[Module:parameters]]
(which parses template parameters, and in particular handles the separate parameter versions of the properties) and
`parse_inline_modifiers()` in [[Module:parse utilities]] (which parses inline modifiers).

The main entry point is `process_list_arguments()`, which takes an object specifying various properties and returns a
list of objects, one per item specified by the user, where the individual objects are much like the objects returned by
`parse_inline_modifiers()`. However, there are other functions provided, in particular to initialize the `param_mods`
structured that is passed to `process_list_arguments()`.

The typical workflow for using this module looks as follows (a slightly simplified version of the code in
[[Module:homophones]]):
{
local export = {}

local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"

...

-- Entry point to be invoked from a template.
function export.show(frame)
	local parent_args = frame:getParent().args

	-- Parameters that don't have corresponding inline modifiers. Note in particular that the items themselves must
	-- be specified this way.
	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[2] = {list = true, required = true, allow_holes = true, default = "term"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
	}

	-- Item properties, available either through separate parameters or inline modifiers.
	local param_mods = {
		alt = {},
		t = {
			-- [[Module:links]] expects the gloss in "gloss".
			item_dest = "gloss",
		},
		gloss = {
			alias_of = "t",
		},
		tr = {},
		ts = {},
		g = {
			-- [[Module:links]] expects the genders in "g". `sublist = true` automatically splits on comma (optionally
			-- with surrounding whitespace).
			item_dest = "genders",
			sublist = true,
		},
		pos = {},
		lit = {},
		id = {},
		sc = {
			-- sc= is distinct from sc1=/sc2= and <sc:...>.
			separate_no_index = true,
			-- Automatically parse as a script code and convert to a script object.
			type = "script",
		},
	}

	local m_param_utils = require(parameter_utilities_module)

	-- This adds "pronunciation qualifiers" to `param_mods`. By default, this consists of "q", "qq", "a", "aa" and
	-- "ref", along with `convert` functions to appropriately parse and convert the values. By default, all but "ref"
	-- have `separate_no_index = true` set, but this can be overridden. The particular properties to add can also be
	-- overridden, and are some subset of "q" (left regular qualifier), "qq" (right regular qualifier), "a" (left
	-- accent qualifier), "aa" (right accent qualifier), "l" (left label), "ll" (right label) and "ref" (references).
	m_param_utils.augment_param_mods_with_pron_qualifiers(param_mods)

	-- This converts the properties in `param_mods` into the appropriate structures for use by `process()` in
	-- [[Module:parameters]] and stores them in `params`.
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	-- This parses the template parameters, including the separate-parameter version of item properties, and stores them
	-- into `args`.
	local args = require(parameters_module).process(parent_args, params)

	local lang = args[1]

	-- This parses inline modifiers and creates corresponding objects, containing the property values specified either
	-- through inline modifiers or separate parameters.
	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1 + offset,
		track_module = "homophones",
		parse_lang_prefix = true,
		lang = lang,
		sc = args.sc.default,
	}

	-- Now do the actual implementation of the template. Generally this should be split into a separate function, often
	-- in a separate module (if the implementation goes in [[Module:foo]], the template interface code goes in
	-- [[Module:foo/templates]]).
	...
}

The `param_mods` structure controls the properties that can be specified by the user for a given item, and is
conceptually very similar to the `param_mods` structure used by `parse_inline_modifiers()`. The key is the name of the
parameter (e.g.  {"t"}, {"pos"}) and the value is a table with optional elements as follows:
* `item_dest`, `convert`, `store`: Same as the corresponding fields in the `param_mods` structure passed to
  `parse_inline_modifiers()`.
* `param_key`: The name of the key used when storing the parameter's value into the `args` object returned by
  [[Module:parameters]]. It is rare that you need to specify this, as it defaults to the parameter's name (the key) and
  this is almost always correct. May be different e.g. in a superseded method for handling the separate no-index pattern
  (where e.g. {{para|sc}} is distinct from {{para|sc1}}), where e.g. the key {"sc"} would be used to hold the value of
  {{para|sc}} and a key like {"listsc"} would be used to hold the value of {{para|sc1}}, {{para|sc2}}, etc.; but prefer
  using `separate_no_index = true` in place of this.
* All other fields are the same as the corresponding fields in the `params` structure passed to the `process()` function
  in [[Module:parameters]]. Some of the more useful field values:
  ** `type`, `set`, `sublist` and associated fields such as `etym_lang`, `family` and `method`: These control parsing
     and conversion of the raw values specified by the user and have the same meaning as in [[Module:parameters]] and
	 also in `parse_inline_modifiers()` (which delegates the actual conversion to [[Module:parameters]]).
  ** `alias_of`: This parameter is an alias of some other parameter. If you have two properties, where one is an alias
     of the other, you will often have to use `item_dest` in concert with `alias_of` so that the aliasing happens both
	 for the inline modifier and separate-parameter versions of the property. As an example, the {"lb"} property in
	 [[Module:nyms]] (which handles {{tl|syn}}, {{tl|ant}}, etc.) is an alias of the {"ll"} property, so the definition
	 of the {"lb"} property needs to specify both {item_dest = "ll"} and {alias_of = "ll"}. As an example where they
	 may not go in concert, many templates support a {"t"} property with alias {"gloss"} for specifying the gloss
	 (definition) of an item, where {"t"} is considered the canonical version but is stored into the {"gloss"} key in
	 the objects returned by `process_list_arguments()` for compatibility with `full_link()` in [[Module:links]]. In
	 this case, the definition of {"t"} specifies {item_dest = "gloss"} and the definition of {"gloss"} specifies
	 {alias_of = "t"}. As another example, many templates support a {"g"} property for specifying a comma-separated list
	 of genders, which is stored into the {"genders"} key in the returned objects, again for compatibility with
	 `full_link()`. The spec for this property specifies {item_dest = "genders"}, but since there is no user-visible
	 {"genders"} alias provided, there is no need for `alias_of` anywhere.
  ** `separate_no_index`: This means that e.g. the {{para|sc}} parameter is distinct from the {{para|sc1}} parameter
     (and thus from the `<sc:...>` inline modifier on the first item). This is typically used to distinguish an overall
	 version of a property from the corresponding item-specific property on the first item. (In this case, for example,
	 {{para|sc}} overrides the script code for all items, while {{para|sc1}} overrides the script code only for the
	 first item.) If not given, and if `require_index` is not given, {{para|sc}} and {{para|sc1}} would have the same
	 meaning and refer to the item-specific property on the first item. When this is given, the overall value can be
	 accessed using the `.default` field of the property value in `args`, e.g. in this case `args.sc.default`.
  ** `require_index`: This means that the non-indexed parameter version of the property is not recognized. E.g. in the
     case of the {"sc"} property, use of the {{para|sc}} parameter would result in an error, while {{para|sc1}} is
	 recognized and specifies the {"sc"} property for the first item.
  ** `list`, `allow_holes`: These should '''not''' be given as they are set by default.
]==]

--[==[
Add "pronunciation qualifiers" to `param_mods`. By default, this consists of {"q"}, {"qq"}, {"a"}, {"aa"} and {"ref"},
along with `convert` functions to appropriately parse and convert the values. By default, all but {"ref"} have
`separate_no_index = true` set, but this can be overridden. The particular properties to add can also be overridden,
and are some subset of "q" (left regular qualifier), "qq" (right regular qualifier), "a" (left
accent qualifier), "aa" (right accent qualifier), "l" (left label), "ll" (right label) and "ref" (references).
]==]
function export.augment_param_mods_with_pron_qualifiers(param_mods, qtypes)
	qtypes = qtypes or {"q", "a", "ref"}
	for _, qtype in ipairs(qtypes) do
		if type(qtype) == "string" then
			qtype = {param = qtype}
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
			param_mods.q = qspec
			param_mods.qq = qspec
		elseif param == "a" or param == "l" then
			local laspec = {
				separate_no_index = get_separate_no_index(true),
				convert = export.parse_labels,
			}
			if param == "a" then
				param_mods.a = laspec
				param_mods.aa = laspec
			else
				param_mods.l = laspec
				param_mods.ll = laspec
			end
		elseif param == "ref" then
			param_mods.ref = {
				item_dest = "refs",
				separate_no_index = get_separate_no_index(false),
				convert = export.parse_references,
			}
		else
			error(("Internal error: Unrecognized qualifier type %s"):format(dump(param)))
		end
	end
end

-- Return true if `k` is a "built-in" (specially recognized) key in a `param_mod` specification. All other keys
-- are forwarded to the structure passed to [[Module:parameters]].
local function param_mod_spec_key_is_builtin(k)
	return k == "param_key" or k == "item_dest" or k == "convert" or k == "overall" or k == "store"
end

function export.augment_params_with_modifiers(params, param_mods)
	local list_with_holes = { list = true, allow_holes = true }
	-- Add parameters for each term modifier.
	for param_mod, param_mod_spec in pairs(param_mods) do
		local param_key = param_mod_spec.param_key or param_mod
		local has_extra_specs = false
		for k, _ in pairs(param_mod_spec) do
			if not param_mod_spec_key_is_builtin(k) then
				has_extra_specs = true
				break
			end
		end
		if not has_extra_specs then
			params[param_key] = list_with_holes
		else
			local param_spec = mw.clone(list_with_holes)
			for k, v in pairs(param_mod_spec) do
				if not param_mod_spec_key_is_builtin(k) then
					param_spec[k] = v
				end
			end
			params[param_key] = param_spec
		end
	end
end

local function make_parse_err(data)
	return function(msg, stack_frames_to_ignore)
		error(("%s: %s%s=%s"):format(
			msg, data.param_mod, (data.termno > 1 or data.param_mod_spec.require_index or
				data.param_mod_spec.separate_no_index) and data.termno or "", data.arg
		), stack_frames_to_ignore
		)
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
						if param_mod_spec.convert then
							-- Beware, this operates *ON TOP OF* the conversion performed by [[Module:parameters]].
							arg = param_mod_spec.convert(arg, parse_err, "separate arg")
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
