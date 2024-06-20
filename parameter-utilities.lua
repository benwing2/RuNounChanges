local export = {}

local dump = mw.dumpObject
local labels_module = "Module:labels"
local languages_module = "Module:languages"
local parameters_module = "Module:parameters"
local parse_utilities_module = "Module:parse utilities"
local references_module = "Module:references"
local scripts_module = "Module:scripts"
local table_module = "Module:table"

local function track(page, track_module)
	return require("Module:debug/track")((track_module or "parameter utilities") .. "/" .. page)
end

-- Table listing the recognized special separator arguments and how they display.
local special_separators = {
	[";"] = "; ",
	["_"] = " ",
	["~"] = " ~ ",
}

--[==[ intro:
The purpose of this module is to facilitate implementation of a template that takes a list of items with associated
properties, which can be specified either through separate parameters (e.g. {{para|t2}}, {{para|pos3}}) or inline
modifiers (`<t:...>`, `<pos:...>`, etc.). Some examples of templates that work this way are {{tl|alter}}/{{tl|alt}};
{{tl|synonyms}}/{{tl|syn}}, {{tl|antonyms}}/{{tl|ant}}, and other "nyms" templates; {{tl|col}}, {{tl|col2}},
{{tl|col3}}, {{tl|col4}} and other columns templates; {{tl|descendant}}/{{tl|desc}}; {{tl|affix}}/{{tl|af}},
{{tl|prefix}}/{{tl|pre}} and related *fix templates; {{tl|affixusex}}/{{tl|afex}} and related templates; {{tl|IPA}};
{{tl|homophones}}; {{tl|rhymes}}; and several others. Not all of them currently use this module, but they should all
eventually be converted to do so. This module can be thought of as a combination of [[Module:parameters]] (which parses
template parameters, and in particular handles the separate parameter versions of the properties) and
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
			-- [[Module:links]] expects the genders in "genders". `sublist = true` automatically splits on comma
			-- (optionally with surrounding whitespace).
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

	-- This parses inline modifiers and creates corresponding objects containing the property values specified either
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
* `item_dest`, `store`: Same as the corresponding fields in the `param_mods` structure passed to
  `parse_inline_modifiers()`.
* `param_key`: The name of the key used when storing the parameter's value into the `args` object returned by
  [[Module:parameters]]. It is rare that you need to specify this, as it defaults to the parameter's name (the key) and
  this is almost always correct. May be different e.g. in a superseded method for handling the separate no-index pattern
  (where e.g. {{para|sc}} is distinct from {{para|sc1}}), where e.g. the key {"sc"} would be used to hold the value of
  {{para|sc}} and a key like {"listsc"} would be used to hold the value of {{para|sc1}}, {{para|sc2}}, etc.; but prefer
  using `separate_no_index = true` in place of this.
* All other fields are the same as the corresponding fields in the `params` structure passed to the `process()` function
  in [[Module:parameters]]. Some of the more useful field values:
  ** `type`, `set`, `sublist`, `convert` and associated fields such as `etym_lang`, `family` and `method`: These control
     parsing and conversion of the raw values specified by the user and have the same meaning as in
	 [[Module:parameters]] and also in `parse_inline_modifiers()` (which delegates the actual conversion to
	 [[Module:parameters]]).
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


local qualifier_spec = {
	type = "qualifier",
	separate_no_index = true,
}

local label_spec = {
	type = "labels",
	separate_no_index = true,
}

local recognized_param_mod_sets = {
	link = {
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
			-- [[Module:links]] expects the genders in "genders".
			item_dest = "genders",
			sublist = true,
		},
		pos = {},
		lit = {},
		id = {},
		sc = {
			separate_no_index = true,
			type = "script",
		},
	},
	lang = {
		lang = {
			require_index = true,
			type = "language",
			etym_lang = true,
		},
	},
	q = {
		q = qualifier_spec,
		qq = qualifier_spec,
	},
	a = {
		a = label_spec,
		aa = label_spec,
	},
	l = {
		l = label_spec,
		ll = label_spec,
	},
	ref = {
		ref = {
			item_dest = "refs",
			type = "references",
		},
	},
}


local function merge_param_mod_settings(orig, additions)
	local shallowcopy = require(table_module).shallowcopy
	local merged = shallowcopy(orig)
	for k, v in pairs(additions) do
		merged[k] = v
		if k == "require_index" then
			merged.separate_no_index = nil
		elseif k == "separate_no_index" then
			merged.require_index = nil
		end
	end
	merged.default = nil
	merged.set = nil
	merged.param = nil
	return merged
end


local function construct_param_mods_error(msg, spec)
	error(("Internal error: %s: %s"):format(msg, dump(spec)))
end

--[==[
Construct the `param_mods` structure used in parsing arguments and inline modifiers from a list of specifications.
A sample invocation looks like this:
{
	local param_mods = require("Module:parameter utilities").construct_param_mods {
		-- We want to require an index for all params (or use separate_no_index, which also requires an index for the
		-- param corresponding to the first item).
		{default = true, require_index = true},
		{set = {"link", "ref", "lang", "q", "l"}},
		-- Override these two to have separate_no_index.
		{param = {"lit", "pos"}, separate_no_index = true},
	}
}

Each specification ...
]==]
function export.construct_param_mods(specs)
	local shallowcopy = require(table_module).shallowcopy
	local param_mods = {}
	local initial_default_specs = {list = true, allow_holes = true}
	local default_specs = initial_default_specs
	for _, spec in ipairs(specs) do
		if spec.default then
			if spec.set or spec.param then
				construct_param_mods_error("Saw `set` and/or `param` key in `default` setting", spec)
			end
			default_specs = merge_param_mod_settings(initial_default_specs, spec.default)
		elseif not spec.set and not spec.param then
			construct_param_mods_error("Spec passed to construct_param_mods() must have either the `default`, `set` or `param` keys set",
				spec)
		else
			if spec.set then
				local sets = spec.set
				if type(sets) ~= "table" then
					sets = {sets}
				end
				local include_set
				if spec.include then
					include_set = require(table_module).listToSet(spec.include)
				end
				local exclude_set
				if spec.exclude then
					exclude_set = require(table_module).listToSet(spec.exclude)
				end
				if include_set and exclude_set then
					construct_param_mods_error("Saw both `include` and `exclude` in the same spec", spec)
				end
				for _, set in ipairs(set) do
					local set_specs = recognized_param_mod_sets[set]
					if not set_specs then
						construct_param_mods_error(("Unrecognized built-in param mod set '%s'"):format(set), spec)
					end
					for set_param, set_param_settings in pairs(set_specs) do
						local include_param
						if include_set then
							include_param = include_set[set_param]
						elseif exclude_set then
							include_param = not exclude_set[set_param]
						else
							include_param = true
						end
						if include_param then
							local merged_settings = merge_param_mod_settings(merge_param_mod_settings(
								param_mods[set_param] or default_specs, set_param_settings), spec)
							param_mods[set_param] = merged_settings
						end
					end
				end
			end
			if spec.param then
				local params = spec.param
				if type(params) ~= "table" then
					params = {params}
				end
				for _, param in ipairs(params) do
					local settings = merge_param_mod_settings(param_mods[param] or default_specs, spec)
					-- If this parameter is an alias of another parameter, we need to copy the specs from the other
					-- parameter, since parse_inline_modifiers() doesn't know about `alias_of` and having the specs
					-- duplicated won't cause problems for [[Module:parameters]]. We also need to set `item_dest` to
					-- point to the `item_dest` of the aliasee (defaulting to the aliasee's value itself), so that
					-- both modifiers write to the same location. Note that this works correctly in the common case of
					-- <t:...> with `item_dest = "gloss"` and <gloss:...> with `alias_of = "t"`, because both will end
					-- up with `item_dest = "gloss"`.
					local aliasee = settings.alias_of
					if aliasee then
						local aliasee_settings = param_mods[aliasee]
						if not aliasee_settings then
							construct_param_mods_error(("Undefined aliasee '%s'"):format(aliasee), spec)
						end
						for k, v in pairs(aliasee_settings) do
							if k ~= "list" and k ~= "allow_holes" and settings[k] == nil then
								settings[k] = v
							end
						end
						if settings.item_dest == nil then
							settings.item_dest = aliasee
						end
					end
					param_mods[param] = settings
				end
			end
		end
	end

	return param_mods
end

--[==[
'''FIXME''': This will be deleted as soon as all new code is pushed, as nothing will rely on this.

Add "pronunciation qualifiers" to `param_mods`. By default, this consists of {"q"}, {"qq"}, {"a"}, {"aa"} and {"ref"},
along with `type` values to appropriately parse and convert the values. By default, all but {"ref"} have
`separate_no_index = true` set. The `qspecs` parameter can be used to override the set of properties added and
optionally the specs for these properties. Its value is a list of specs, each of which is either a string (a parameter
set to add) or an object containing properties `param` (the parameter set to add) and any additional properties to set
in the parameter specs. Any specified properties override default values (see below). For example, if
`separate_no_index` is specified and set to {true} or {false}, it overrides the default value of `separate_no_index`
associated with the parameters specified by `param`. The possible values of `param`, the respective parameters
controlled and their default values are specified in the following table:

{|class="wikitable"
! value of `param` !! parameters controlled !! meaning !! destination field !! default for `separate_no_index`
|-
| {"q"} || {"q"}, {"qq"} || left and right regular qualifier || `q`, `qq` || {true}
|-
| {"a"} || {"a"}, {"aa"} || left and right comma-separated list of accent qualifiers || `a`, `aa` || {true}
|-
| {"l"} || {"l"}, {"ll"} || left and right comma-separated list of labels || `l`, `ll` || {true}
|-
| {"ref"} || {"ref"} || references of the format used by [[Module:references]] || `refs` || {false}
|}
]==]
function export.augment_param_mods_with_pron_qualifiers(param_mods, qspecs)
	qspecs = qspecs or {"q", "a", "ref"}
	for _, qspec in ipairs(qspecs) do
		if type(qspec) == "string" then
			qspec = {param = qspec}
		end
		local param = qspec.param

		local function make_spec(typ, default_separate_no_index, item_dest)
			local separate_no_index = qspec.separate_no_index
			if separate_no_index == nil then
				separate_no_index = default_separate_no_index
			end
			local spec = {
				separate_no_index = separate_no_index,
				type = qspec.type or typ,
				item_dest = qspec.item_dest or item_dest,
			}
			for k, v in pairs(qspec) do
				if k ~= "param" and k ~= "separate_no_index" and k ~= "type" and k ~= "item_dest" then
					spec[k] = v
				end
			end
			return spec
		end

		if param == "q" then
			local qspec = make_spec("qualifier", true)
			param_mods.q = qspec
			param_mods.qq = qspec
		elseif param == "a" or param == "l" then
			local laspec = make_spec("labels", true)
			if param == "a" then
				param_mods.a = laspec
				param_mods.aa = laspec
			else
				param_mods.l = laspec
				param_mods.ll = laspec
			end
		elseif param == "ref" then
			local refspec = make_spec("references", false, "refs")
			param_mods.ref = refspec
		else
			error(("Internal error: Unrecognized qualifier type %s"):format(dump(param)))
		end
	end
end

-- Return true if `k` is a "built-in" (specially recognized) key in a `param_mod` specification. All other keys
-- are forwarded to the structure passed to [[Module:parameters]].
local function param_mod_spec_key_is_builtin(k)
	return k == "param_key" or k == "item_dest" or k == "overall" or k == "store"
end

--[==[
Convert the properties in `param_mods` into the appropriate structures for use by `process()` in [[Module:parameters]]
and store them in `params`. If `overall_only` is given, only store the properties in `param_mods` that correspond to
overall (non-item-specific) parameters. Currently this only happens when `separate_no_index` is specified.
]==]
function export.augment_params_with_modifiers(params, param_mods, overall_only)
	if overall_only then
		for param_mod, param_mod_spec in pairs(param_mods) do
			local param_key = param_mod_spec.param_key or param_mod
			if param_mod_spec.separate_no_index then
				local param_spec = {}
				for k, v in pairs(param_mod_spec) do
					if k ~= "separate_no_index" and not param_mod_spec_key_is_builtin(k) then
						param_spec[k] = v
					end
				end
				params[param_key] = param_spec
			end
		end
	else
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
end

--[==[
Return true if `k`, a key in an item, refers to a property of the item (is not one of the specially stored values).
Note that `lang` and `sc` are considered properties of the item, although `lang` is set when there's a language
prefix and both `lang` and `sc` may be set from default values specified in the `data` structure passed into
`process_list_arguments()`. If you don't want these treated as property keys, you need to check for them yourself.
]==]
function export.item_key_is_property(k)
	return k ~= "term" and k ~= "termlang" and k ~= "termlangs" and k ~= "itemno" and k ~= "orig_index" and
		k ~= "separator"
end

--[==[
Parse inline modifiers and create corresponding objects containing the property values specified either through inline
modifiers or separate parameters. `data` is an object containing the following properties:
* `args` ('''required'''): The object of parsed arguments returned by `process()` in [[Module:parameters]].
* `param_mods` ('''required'''): A structure describing the possible inline modifiers and their properties. See the
  introductory comment above.
* `termarg` ('''required'''): The argument containing the items with attached inline modifiers to be parsed. Usually a
  numeric value such as {1} or {2}.
* `track_module` ('''recommended'''): The name of the calling module, for use in adding tracking pages that are used
  internally to track pages containing template invocations with certain properties. Example properties tracked are
  missing items with corresponding properties as well as missing items without corresponding properties (which are
  skipped entirely). To find out the exact properties tracked and the name of the tracking pages, read the code.
* `term_dest`: The field to store the value of the item itself into, after inline modifiers and (if allowed) language
  prefixes are stripped off. Defaults to {"term"}.
* `parse_lang_prefix`: If true, allow and parse off a language code prefix attached to items followed by a colon, such
  as {la:minūtia} or {grc:[[σκῶρ|σκατός]]}. Etymology-only languages are allowed. Inline modifiers can be attached to
  such items. The exact syntax allowed is as specified in the `parse_term_with_lang()` function in
  [[Module:parse utilities]]. If `allow_multiple_lang_prefixes` is given, a comma-separated list of language prefixes
  can be attached to an item. The resulting language object is stored into the `termlang` field, and also into the
  `lang` field (or in the case of `allow_multiple_lang_prefixes`, the list of language objects is stored into the
  `termlangs` field, and the first specified object is stored in the `lang` field).
* `allow_multiple_lang_prefixes`: If given in conjunction with `parse_lang_prefix`, multiple comma-separated language
  code prefixes can be given. See `parse_lang_prefix` above.
* `allow_bad_lang_prefixes`: If given in conjunction with `parse_lang_prefix`, unrecognized language prefixes do not
  trigger an error, but are simply ignored (and not stripped off the item). Note that, regardless of whether this is
  given, prefixes before a colon do not trigger an error if they do not have the form of a language prefix or if a space
  follows the colon. It is not recommended that this be given because typos in language prefixes will not trigger an
  error and will tend to remain unfixed.
* `lang`: The language code for the language of the items. In general it is not necessary to specify this as this
  function only parses inline modifiers and doesn't actually format the resulting items. However, if specified, it is
  used for certain purposes:
  *# It specifies the default for the `lang` property of returned objects if not otherwise set (e.g. by a language
     prefix).
  *# It is used to initialize an internal cache for speeding up language-code parsing (primarily useful if the same
     language code may appear in several items, such as with {{tl|col}} and related templates).
* `sc`: The script code for the items. In general, as with `lang`,  it is not necessary to specify this. However, if
  specified, it is used to supply the default for the `sc` property of returned objects if not otherwise set (e.g. by
  the {{para|sc<var>N</var>}} parameter or `<sc:...>` inline modifier).
* `disallow_custom_separators`: If specified, disallow specifying a bare semicolon as an item value to indicate that the
  item's previous separator should be a semicolon. By default, the previous separator of each item is considered to be
  an empty string (for the first item) and otherwise a comma + space, unless either the preceding item is a bare
  semicolon (which causes the following item's previous separator to be a semicolon + space) or an item has an embedded
  comma in it (which causes ''all'' items other than the first to have their previous separator be a semicolon + space).
  The previous separator of each item is set on the item's `separator` property. Bare semicolons do not count when
  indexing items using separate parameters. For example, the following is correct:
  ** {{tl|template|lang|item 1|q1=qualifier 1|;|item 2|q2=qualifier 2}}
  If `disallow_custom_separators` is specified, however, the `separator` property is not set and bare semicolons do not
  get any special treatment.
* `dont_skip_items`: Normally, items that are completely unspecified (have no term and no properties) are skipped and
  not inserted into the returned list of items. (Such items cannot occur if `disallow_holes = true` is set on the term
  specification in the `params` structure passed to `process()` in [[Module:parameters]]. It is generally recommended
  to do so unless a specific meaning is associated the term value being missing.) If `dont_skip_items` is set, however,
  items are never skipped, and completely unspecified items will be returned along with others. (They will not have
  the term or any properties set, but will have the normal non-property fields set; see below.)
* `stop_when`: If specified, a function to determine when to prematurely stop processing items. It is passed a single
  argument, an object containing the following fields:
  ** `term`: The raw term, prior to parsing off language prefixes and inline modifiers (since the processing of
     `stop_when` happens before parsing the term).
  ** `any_param_at_index`: True if any separate property parameters exist for this item.
  ** `orig_index`: Same as `orig_index` below.
  ** `itemno`: Same as `itemno` below.
  ** `stored_itemno`: The index where this item will be stored into the returned items table. This may differ from
     `itemno` due to skipped items (it will never be different if `dont_skip_items` is set).
  The function should return true to stop processing items and return the ones processed so far (not including the item
  currently being processed). This is used, for example, in [[Module:alternative forms]], where an unspecified item
  signal the end of items and the start of labels.

The return value is a list of items. There will be one field set for each specified property (either through inline
modifiers or separate parameters). In addition, the following fields may be set:
* `term`: The term portion of the item (minus inline modifiers and language prefixes). {nil} if no term was given.
* `orig_index`: The original index into the item in the items table returned by `process()` in [[Module:parameters]].
  This may differ from `itemno` if there are raw semiclons and `disallow_custom_separators` is not given.
* `itemno`: The logical index of the item. The index of separate parameters corresponds to this index. This may be
  different from `orig_index` in the presence of raw semicolons; see above.
* `separator`: The separator to display before the term. Always set unless `disallow_custom_separators` is given, in
  which case it is not set.
* `termlang`: If there is a language prefix, the corresponding language object is stored here (only if
  `parse_lang_prefix` is set and `allow_multiple_lang_prefixes` is not set).
* `termlangs`: If there is are language prefixes and both `parse_lang_prefix` and `allow_multiple_lang_prefixes` are
   set, the list of corresponding language objects is stored here.
* `lang`: The language object of the item. This is set when either (a) there is a language prefix parsed off (if
  multiple prefixes are allowed, this corresponds to the first one); (b) the `lang` property is allowed and specified;
  (c) neither (a) nor (b) apply and the `lang` field of the overall `data` object is set, providing a default value.
* `sc`: The script object of the item. This is set when either (a) the `sc` property is allowed and specified; (b)
  `sc` isn't otherwise set and the `sc` field of the overall `data` object is set, providing a default value.
]==]
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

	local itemno = 0
	for i = 1, maxmaxindex do
		local term = term_args[i]
		if data.disallow_custom_separators or not special_separators[term] then
			itemno = itemno + 1

			-- Compute whether any of the separate indexed params exist for this index.
			local any_param_at_index = term ~= nil
			if not any_param_at_index then
				for k, v in pairs(data.args) do
					-- Look for named list parameters. We check:
					-- (1) key is a string (excludes the term param, which is a number);
					-- (2) value is a table, i.e. a list;
					-- (3) v.maxindex is set (i.e. allow_holes was used);
					-- (4) the value has an entry at index `itemno` (the current logical index).
					if type(k) == "string" and type(v) == "table" and v.maxindex and v[itemno] then
						any_param_at_index = true
						break
					end
				end
			end

			if data.stop_when and data.stop_when {
				term = term,
				any_param_at_index = any_param_at_index,
				orig_index = i,
				itemno = itemno,
				stored_itemno = #items + 1,
			} then
				break
			end

			-- If any of the params used for formatting this term is present, create a term and add it to the list.
			if not data.dont_skip_items and not any_param_at_index then
				track("skipped-term", data.track_module)
			else
				if not term then
					track("missing-term", data.track_module)
				end
				local termobj = {
					itemno = itemno,
					orig_index = i,
				}
				if not data.disallow_custom_separators then
					termobj.separator = i == 1 and "" or special_separators[term_args[i - 1]]
				end

				-- Parse all the term-specific parameters and store in `termobj`.
				for param_mod, param_mod_spec in pairs(data.param_mods) do
					local dest = param_mod_spec.item_dest or param_mod
					local param_key = param_mod_spec.param_key or param_mod
					local arg = data.args[param_key] and data.args[param_key][itemno]
					if arg then
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
						if termlangs then
							-- If we couldn't parse a language code, don't overwrite an existing setting in `lang`
							-- that may have originated from a separate |langN= param.
							if data.allow_multiple_lang_prefixes then
								termobj.termlangs = termlangs
								termobj.lang = termlangs and termlangs[1] or nil
							else
								termobj.termlang = termlangs
								termobj.lang = termlangs
							end
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

				if not data.disallow_custom_separators then
					-- If the displayed term (from .term/etc. or .alt) has an embedded comma, use a semicolon to join
					-- the terms.
					local term_text = termobj[term_dest] or termobj.alt
					if not use_semicolon and term_text then
						if term_text:find(",", 1, true) then
							use_semicolon = true
						end
					end
				end

				table.insert(items, termobj)
			end
		end
	end

	if not data.disallow_custom_separators then
		-- Set the default separator of all those items for which a separator wasn't explicitly given to comma
		-- (or semicolon if any items have embedded commas).
		for i, item in ipairs(items) do
			if not item.separator then
				item.separator = use_semicolon and "; " or ", "
			end
		end
	end

	return items
end


return export
