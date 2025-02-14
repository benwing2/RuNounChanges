local export = {}

local debug_track_module = "Module:debug/track"
local languages_module = "Module:languages"
local parameters_module = "Module:parameters"
local parse_interface_module = "Module:parse interface"
local parse_utilities_module = "Module:parse utilities"
local table_module = "Module:table"

local dump = mw.dumpObject

--[==[
Loaders for functions in other modules, which overwrite themselves with the target function when called. This ensures
modules are only loaded when needed, retains the speed/convenience of locally-declared pre-loaded functions, and has no
overhead after the first call, since the target functions are called directly in any subsequent calls.
]==]
local function debug_track(...)
	debug_track = require(debug_track_module)
	return debug_track(...)
end

local function length(...)
	length = require(table_module).length
	return length(...)
end

local function list_to_set(...)
	list_to_set = require(table_module).listToSet
	return list_to_set(...)
end

local function parse_term_with_lang(...)
	parse_term_with_lang = require(parse_utilities_module).parse_term_with_lang
	return parse_term_with_lang(...)
end

local function parse_inline_modifiers(...)
	parse_inline_modifiers = require(parse_interface_module).parse_inline_modifiers
	return parse_inline_modifiers(...)
end

local function process_params(...)
	process_params = require(parameters_module).process
	return process_params(...)
end

local function shallow_copy(...)
	shallow_copy = require(table_module).shallowCopy
	return shallow_copy(...)
end

----------------- end loaders ----------------

local function track(page, track_module)
	return debug_track((track_module or "parameter utilities") .. "/" .. page)
end

-- Throw an error prefixed with the words "Internal error" (and suffixed with a dumped version of `spec`, if provided).
-- This is for logic errors in the code itself rather than template user errors.
local function internal_error(msg, spec)
	if spec then
		msg = ("%s: %s"):format(msg, dump(spec))
	end
	error(("Internal error: %s"):format(msg))
end

-- Table listing the default recognized special separator arguments and how they display.
export.default_special_separators = {
	[";"] = "; ",
	["_"] = " ",
	["~"] = " ~ ",
}

-- Table listing the default recognized special separator arguments and how they display.
export.default_special_continuations = {
	["etc."] = {display = "''etc.''"},
}

--[==[ intro:
The purpose of this module is to facilitate implementation of templates that can have arguments specified either through
inline modifiers or separate parameters. There are two types of templates supported: those that take a list of items
with associated properties, which can be specified either through indexed separate parameters (e.g. {{para|t2}},
{{para|pos3}}) or inline modifiers (`<t:...>`, `<pos:...>`, etc.); and those that take a single term, whose properties
can be specified through non-indexed separate parameters (e.g. {{para|t}} or {{para|pos}}) or inline modifiers. Both
types of templates can optionally have subitems in the term parameter(s), where the subitems are typically (but not
necessarily) separated with commas and each subitem can have its own inline modifiers.

Some examples of templates that take a list of items are {{tl|alter}}/{{tl|alt}}; {{tl|synonyms}}/{{tl|syn}},
{{tl|antonyms}}/{{tl|ant}}, and other "nyms" templates; {{tl|col}}, {{tl|col2}}, {{tl|col3}}, {{tl|col4}} and other
column templates; {{tl|descendant}}/{{tl|desc}}; {{tl|affix}}/{{tl|af}}, {{tl|prefix}}/{{tl|pre}} and related *fix
templates; {{tl|affixusex}}/{{tl|afex}} and related templates; {{tl|IPA}}; {{tl|homophones}}; {{tl|rhymes}}; and several
others.

Examples of templates that take a single item are form-of templates ({{tl|inflection of}}/{{tl|infl of}},
{{tl|form of}}, and specific templates such as {{tl|alt form}}/{{tl|alternative form of}},
{{tl|abbr of}}/{{tl|abbreviation of}}, {{tl|clipping of}}, and many others); for etymology templates
({{tl|bor}}/{{tl|borrowed}}, {{tl|der}}/{{tl|derived}}, etc. as well as `misc_variant` templates like {{tl|ellipsis}},
{{tl|abbrev}}, {{tl|clipping}}, {{tl|reduplication}} and the like); and other templates that take an argument structure
similar to {{tl|l}} or {{tl|m}}.

This module can be thought of as a combination of [[Module:parameters]] (which parses template parameters, and in
particular handles the separate parameter versions of the properties) and `parse_inline_modifiers()` in
[[Module:parse utilities]] (which parses inline modifiers).

The two main entry points are `parse_list_with_inline_modifiers_and_separate_params()` (for templates that take a list
of items) and `parse_term_with_inline_modifiers_and_separate_params()` (for templates that take a single item). However,
there are other functions provided, e.g. to initialize the `param_mods` structure that is passed to the two entry
points.

The typical workflow for using `parse_list_with_inline_modifiers_and_separate_params()` looks as follows (a slightly
simplified version of the code in [[Module:nyms]]):
{
local export = {}

local parameter_utilities_module = "Module:parameter utilities"

...

-- Entry point to be invoked from a template.
function export.show(frame)
	local parent_args = frame:getParent().args

	-- Parameters that don't have corresponding inline modifiers. Note in particular that the parameter corresponding to
	-- the items themselves must be specified this way, and must specify either `allow_holes = true` (if the user can
	-- omit terms, typically by specifying the term using |altN= or <alt:...> so that they remain unlinked) or
	-- `disallow_holes = true` (if omitting terms is not allowed). (If neither `allow_holes` nor `disallow_holes` is
	-- specified, an error is thrown in parse_list_with_inline_modifiers_and_separate_params().)
	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = {list = true, allow_holes = true, required = true, default = "term"},
	}

    local m_param_utils = require(parameter_utilities_module)

	-- This constructs the `param_mods` structure by adding well-known groups of parameters (such as all the parameters
	-- associated with based on full_link() in [[Module:links]], with default properties that can be overridden. This is
	-- easier and less error-prone than manually specifying the `param_mods` structure (see below for how this would
	-- look). Here, we specify the group "link" (consisting of all the link parameters for use with full_link()), group
	-- "ref" (which adds the "ref" parameter for specifying references), group "l" (which adds the "l" and "ll"
	-- parameters for specifying labels) and group "q" (which adds the "q" and "qq" parameters for specifying regular
	-- qualifiers). By default, labels and qualifiers have `separate_no_index` set so that e.g. |q1= is distinct from
	-- |q=, the former specifying the left qualifier for the first item and the latter specifying the overall left
	-- qualifier. For compatibility, we override the `separate_no_index` setting for the group "q", which causes |q= and
	-- |q1= to be the same, and likewise for |qq= and |qq1=. Finally, also for compatibility, we add an "lb" parameter
	-- that is an alias of "ll" (in all respects; |lb= is the same as |ll=, |lb1= is the same as |ll1=, <lb:...> is the
	-- same as <ll:...>, etc.).
	local param_mods = m_param_utils.construct_param_mods {
		{group = {"link", "ref", "l"}},
		{group = "q", separate_no_index = false},
		{param = "lb", alias_of = "ll"},
	}

	-- This processes the raw arguments in `parent_args`, parses inline modifiers and creates corresponding objects
	-- containing the property values specified either through inline modifiers or separate parameters.
	local items, args = m_param_utils.parse_list_with_inline_modifiers_and_separate_params {
		params = params,
		param_mods = param_mods,
		raw_args = parent_args,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "nyms",
		lang = 1,
		sc = "sc.default",
	}

	local lang = args[1]

	-- Now do the actual implementation of the template. Generally this should be split into a separate function, often
	-- in a separate module (if the implementation goes in [[Module:foo]], the template interface code goes in
	-- [[Module:foo/templates]]).
	...
}

The `param_mods` structure controls the properties that can be specified by the user for a given item, and is
conceptually very similar to the `param_mods` structure used by `parse_inline_modifiers()`. The key is the name of the
parameter (e.g. {"t"}, {"pos"}) and the value is a table with optional elements as follows:
* `item_dest`, `store`: Same as the corresponding fields in the `param_mods` structure passed to
  `parse_inline_modifiers()`.
* `type`, `set`, `sublist`, `convert` and associated fields such as `family` and `method`: These control parsing and
  conversion of the raw values specified by the user and have the same meaning as in [[Module:parameters]] and also in
  `parse_inline_modifiers()` (which delegates the actual conversion to [[Module:parameters]]). These fields — and for
  that matter, all fields other than `item_dest`, `store` and `overall` — are forwarded to the `process()` function in
  [[Module:parameters]].
* `alias_of`: This parameter is an alias of some other parameter. This spec is recognized only by `process()` in
  [[Module:parameters]], and not by `parse_inline_modifiers()`; to set up an alias in `parse_inline_modifiers()`, you
  need to make sure (using `item_dest`) that both the alias and aliasee modifiers store their values in the same
  location, and you need to copy the remaining properties from the aliasee's spec to the aliasing modifier's spec. All
  of this happens automatically if you generate the `param_mods` structure using `construct_param_mods()`.
* `require_index`: This means that the non-indexed parameter version of the property is not recognized. E.g. in the
  case of the {"sc"} property, use of the {{para|sc}} parameter would result in an error, while {{para|sc1}} is
  recognized and specifies the {"sc"} property for the first item. The default, if neither `require_index` nor
  `separate_no_index` is given, is for {{para|sc}} and {{para|sc1}} to mean the same thing (both would specify the
  {"sc"} property of the first item). Note that `require_index` and `separate_no_index` are mutually exclusive, and if
  either one is specified during processing by `construct_param_mods()`, the other one is automaticallly turned off.
* `separate_no_index`: This means that e.g. the {{para|sc}} parameter is distinct from the {{para|sc1}} parameter
  (and thus from the `<sc:...>` inline modifier on the first item). This is typically used to distinguish an overall
  version of a property from the corresponding item-specific property on the first item. (In this case, for example,
  {{para|sc}} overrides the script code for all items, while {{para|sc1}} overrides the script code only for the
  first item.) If not given, and if `require_index` is not given, {{para|sc}} and {{para|sc1}} would have the same
  meaning and refer to the item-specific property on the first item. When this is given, the overall value can be
  accessed using the `.default` field of the property value in `args`, e.g. in this case `args.sc.default`. Note that
  (as mentioned above) `require_index` and `separate_no_index` are mutually exclusive, and if either one is specified
  during processing by `construct_param_mods()`, the other one is automaticallly turned off.
* `list`, `allow_holes`, `disallow_holes`: These should '''not''' be given. `list` and `allow_holes` are automatically
  set for all parameter specs added to the `params` structure used by `process()` in [[Module:parameters]], and
  `disallow_holes` clashes with `allow_holes`.

For the above workflow example, the call to `construct_param_mods()` generates the following `param_mods` structure:

{
local param_mods = {
	-- the parameters generated by group "link"
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

	-- the parameters generated by group "ref"
	ref = {
		item_dest = "refs",
		type = "references",
	},

	-- the parameters generated by group "l"
	l = {
		type = "labels",
		separate_no_index = true,
	},
	ll = {
		type = "labels",
		separate_no_index = true,
	},

	-- the parameters generated by group "q"; note that `separate_no_index = true` would be set, but is overridden
	-- (specifying `separate_no_index = false` in the `param_mods` structure is equivalent to not specifying it at all)
	q = {
		type = "qualifier",
		separate_no_index = false,
	},
	qq = {
		type = "qualifier",
		separate_no_index = false,
	},

	-- the parameter generated by the individual "lb" parameter spec; note that only `alias_of` was explicitly given,
	-- while `item_dest` is automatically set so that inline modifier <lb:...> stores into the same place as <ll:...>,
	-- and the other specs are copied from the `ll` spec so `lb` works like `ll` in all regards
	lb = {
		alias_of = "ll",
		item_dest = "ll",
		type = "labels",
		separate_no_index = true,
	},
}
}
]==]


local qualifier_spec = {
	type = "qualifier",
	separate_no_index = true,
}

local label_spec = {
	type = "labels",
	separate_no_index = true,
}

local recognized_param_mod_groups = {
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
	local merged = shallow_copy(orig)
	for k, v in pairs(additions) do
		merged[k] = v
		if k == "require_index" then
			merged.separate_no_index = nil
		elseif k == "separate_no_index" then
			merged.require_index = nil
		end
	end
	merged.default = nil
	merged.group = nil
	merged.param = nil
	merged.exclude = nil
	merged.include = nil
	return merged
end


local function verify_type(spec, param, typ1, typ2)
	if not spec[param] then
		return
	end
	local val = spec[param]
	if type(val) ~= typ1 and (not typ2 or type(val) ~= typ2) then
		internal_error(("Parameter `%s` must be a %s%s but saw a %s"):format(param, typ1, typ2 and " or " .. typ2 or "",
			type(val)), spec)
	end
end

local function verify_well_constructed_spec(spec)
	local num_control = (spec.default and 1 or 0) + (spec.group and 1 or 0) + (spec.param and 1 or 0)
	if num_control == 0 then
		internal_error(
			"Spec passed to construct_param_mods() must have either the `default`, `group` or `param` keys set", spec)
	end
	if num_control > 1 then
		internal_error(
			"Exactly one of `default`, `group` or `param` must be set in construct_param_mods() spec", spec)
	end
	if spec.list or spec.allow_holes then
		-- FIXME: We need to support list = "foo" for list parameters that are stored in e.g. 2=, foo2=, foo3=, etc.
		internal_error("`list` and `allow_holes` may not be set; they are automatically set when constructing the " ..
			"corresponding spec in the `params` object passed to [[Module:parameters]]", spec)
	end
	if spec.disallow_holes then
		internal_error("`disallow_holes` may not be set; it conflicts with `allow_holes`, which is automatically " ..
			"set when constructing the corresponding spec in the `params` object passed to [[Module:parameters]]", spec)
	end
	if spec.include and spec.exclude then
		internal_error("Saw both `include` and `exclude` in the same spec", spec)
	end
	if (spec.include or spec.exclude) and not spec.group then
		internal_error(
			"`include` and `exclude` can only be specified along with `group`, not with `default` or `param`", spec)
	end
	verify_type(spec, "group", "string", "table")
	verify_type(spec, "param", "string", "table")
	verify_type(spec, "include", "table")
	verify_type(spec, "exclude", "table")
end


--[==[
Construct the `param_mods` structure used in parsing arguments and inline modifiers from a list of specifications.
A sample invocation (a slightly simplified version of the actual invocation associated with {{tl|affix}} and related
templates) looks like this:
{
	local param_mods = require("Module:parameter utilities").construct_param_mods {
		-- We want to require an index for all params (or use separate_no_index, which also requires an index for the
		-- param corresponding to the first item).
		{default = true, require_index = true},
		{group = {"link", "ref", "lang", "q", "l"}},
		-- Override these two to have separate_no_index.
		{param = {"lit", "pos"}, separate_no_index = true},
	}
}

Each specification either sets the default value for further parameter specs or adds one or more parameters. Parameters
can be added directly using `param`, or groups of predefined parameters can be added using `group`. Specifications are
one of three types:
# Those that set the default properties for future-added parameters. These contain {default = true} as one of the
  properties of the spec. Specs are processed in order and you can change the defaults mid-way through.
# Those that add the parameters associated with one or more pre-defined groups. These contain {group = "group"} or
  {group = {"group1", "group2", ...}}. The pre-defined parameter groups and their associated properties are listed
  below. The pre-defined properties of parameters in a group override properties associated with a {default = true}
  spec, and are in turn overridden by any properties given directly in the spec itself. Note as well that setting the
  `separate_no_index` property will automatically cause the `require_index` property to be unset and vice-versa, as the
  two are mutually exclusive. (This happens in the example above, where the {separate_no_index = true} setting
  associated with the params {"lit"} and {"pos"} cancels out the {require_index = true} default setting, as well as less
  obviously with the pre-defined {"sc"} property of the {"link"} group, the {"q"} and {"qq"} properties of the {"q"}
  group, and the {"l"} and {"ll"} properties of the {"l"} group, all of which have an associated pre-defined property
  {separate_no_index = true}, which overrides and cancels out the {require_index = true} default setting. Finally, when
  adding the parameters of a group, you can request the only a subset of the parameters be added using either the
  `include` or `exclude` properties, each of whose values is a list of parameters that specify (respectively) the
  parameters to include (all other parameters of the group are excluded) or to exclude (all other parameters of the
  group are included). This is used, for example, in [[Module:romance etymology]] and [[Module:it-etymology]], which
  specify {group = "link", exclude = {"tr", "ts", "sc"}} to exclude link parameters that aren't relevant to Latin-script
  languages such as the Romance languages, and conversely in [[Module:IPA/templates]], which specifies
  {group = "link", include = {"t", "gloss", "pos"}} to include only the specified parameters for use with {{tl|IPA}}.
# Those that add individual parameters. These contain {param = "param"} or {param = {"param1", "param2", ...}}, the
  latter syntax used to control a set of parameters together. The resulting spec is formed by initializing the
  parameter's settings with any previously-specified default properties (using a spec containing {default = true}) if
  the parameter hasn't already been initialized, and then overriding the resulting settings with any settings given
  directly in the specification. In the above example, the {"lit"} and {"pos"} parameters were previously initialized
  through the {"link"} group (specified in the second of the three specifications) but ended up with
  {require_index = true} due to the {default = true} spec (the first of the three specifications). We override these
  two parameters to have {separate_no_index = true} (which, as mentioned above, cancels out {require_index = true}).
  This is done so that {{tl|affix}} and related templates have {{para|pos}} and {{para|lit}} parameters distinct from
  {{para|pos1}} and {{para|lit1}}, which are used to specify an overall part of speech (which applies to all parts of
  the affix, as opposed to applying to just one element of the expression) or a literal definition for the entire
  expression (instead of just for one element of the expression).

The built-in parameter groups are as follows:

{|class="wikitable"
! Group !! Group meaning !! Parameter !! Parameter meaning !! Default properties
|-
| rowspan=10| `link`
| rowspan=10| link parameters; same as those available on {{tl|l}}, {{tl|m}} and other linking templates
| `alt` || display text, overriding the term's display form || —
|-
| `t` || gloss (translation) of a non-English term || {item_dest = "gloss"}
|-
| `gloss` || gloss (translation); same as `t` || {alias_of = "t"}
|-
| `tr` || transliteration of a non-Latin-script term; only needed if the automatic transliteration is incorrect or unavailable (e.g. in Hebrew, which doesn't have automatic transliteration) || —
|-
| `ts` || transcription of a non-Latin-script term, if the transliteration is markedly different from the actual pronunciation; should not be used for IPA pronunciations || —
|-
| `g` || comma-separated list of genders; whitespace may surround the comma and will be ignored || {item_dest = "genders", sublist = true}
|-
| `pos` || part of speech for the term || —
|-
| `lit` || literal meaning (translation) of the term || —
|-
| `id` || a sense ID for the term, which links to anchors on the page set by the {{tl|senseid}} template || —
|-
| `sc` || the script code (see [[Wiktionary:Scripts]]) for the script that the term is written in; rarely necessary, as the script is autodetected (in most cases, correctly) || {separate_no_index = true, type = "script"}
|-
| rowspan=2| `q`
| rowspan=2| left and right normal qualifiers (as displayed using {{tl|q}})
| `q` || left normal qualifier || {separate_no_index = true, type = "qualifier"}
|-
| `qq` || right normal qualifier || {separate_no_index = true, type = "qualifier"}
|-
| rowspan=2| `a`
| rowspan=2| left and right accent qualifiers (as displayed using {{tl|a}})
| `a` || comma-separated list of left accent qualifiers; whitespace must not surround the comma || {separate_no_index = true, type = "labels"}
|-
| `aa` || comma-separated list of right accent qualifiers; whitespace must not surround the comma || {separate_no_index = true, type = "labels"}
|-
| rowspan=2| `l`
| rowspan=2| left and right labels (as displayed using {{tl|lb}}, but without categorizing)
| `l` || comma-separated list of left labels; whitespace must not surround the comma || {separate_no_index = true, type = "labels"}
|-
| `ll` || comma-separated list of right labels; whitespace must not surround the comma || {separate_no_index = true, type = "labels"}
|-
| `ref`
| reference(s) (in the format accepted by [[Module:references]]; see also the documentation for the {{para|ref}} parameter to {{tl|IPA}})
| `ref` || one or more references, in the format accepted by [[Module:references]] || {item_dest = "refs", type = "references"}
|-
| `lang`
| language for an individual term (provided for compatibility; it is preferred to specify languages for individual terms using language prefixes instead)
| `lang` || language code (see [[Wiktionary:Languages]]) for the term || {require_index = true, type = "language"}
|}
]==]
function export.construct_param_mods(specs)
	local param_mods = {}
	local default_specs = {}
	for _, spec in ipairs(specs) do
		verify_well_constructed_spec(spec)
		if spec.default then
			-- This will have an extra `default` field in it, but it will be erased by merge_param_mod_settings()
			default_specs = spec
		else
			if spec.group then
				local groups = spec.group
				if type(groups) ~= "table" then
					groups = {groups}
				end
				local include_set
				if spec.include then
					include_set = list_to_set(spec.include)
				end
				local exclude_set
				if spec.exclude then
					exclude_set = list_to_set(spec.exclude)
				end
				for _, group in ipairs(groups) do
					local group_specs = recognized_param_mod_groups[group]
					if not group_specs then
						internal_error(("Unrecognized built-in param mod group '%s'"):format(group), spec)
					end
					for group_param, group_param_settings in pairs(group_specs) do
						local include_param
						if include_set then
							include_param = include_set[group_param]
						elseif exclude_set then
							include_param = not exclude_set[group_param]
						else
							include_param = true
						end
						if include_param then
							local merged_settings = merge_param_mod_settings(merge_param_mod_settings(
								param_mods[group_param] or default_specs, group_param_settings), spec)
							param_mods[group_param] = merged_settings
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
							internal_error(("Undefined aliasee '%s'"):format(aliasee), spec)
						end
						for k, v in pairs(aliasee_settings) do
							if settings[k] == nil then
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

-- Return true if `k` is a "built-in" (specially recognized) key in a `param_mod` specification. All other keys
-- are forwarded to the structure passed to [[Module:parameters]].
local function param_mod_spec_key_is_builtin(k)
	return k == "item_dest" or k == "overall" or k == "store"
end

--[==[
Convert the properties in `param_mods` into the appropriate structures for use by `process()` in [[Module:parameters]]
and store them in `params`. If `overall_only` is given, only store the properties in `param_mods` that correspond to
overall (non-item-specific) parameters. Currently this only happens when `separate_no_index` is specified.
]==]
function export.augment_params_with_modifiers(params, param_mods, overall_only)
	if overall_only then
		for param_mod, param_mod_spec in pairs(param_mods) do
			if overall_only == "always" or param_mod_spec.separate_no_index then
				local param_spec = {}
				for k, v in pairs(param_mod_spec) do
					if k ~= "separate_no_index" and k ~= "require_index" and not param_mod_spec_key_is_builtin(k) then
						param_spec[k] = v
					end
				end
				params[param_mod] = param_spec
			end
		end
	else
		local list_with_holes = { list = true, allow_holes = true }
		-- Add parameters for each term modifier.
		for param_mod, param_mod_spec in pairs(param_mods) do
			local has_extra_specs = false
			for k in pairs(param_mod_spec) do
				if not param_mod_spec_key_is_builtin(k) then
					has_extra_specs = true
					break
				end
			end
			if not has_extra_specs then
				params[param_mod] = list_with_holes
			else
				local param_spec = mw.clone(list_with_holes)
				for k, v in pairs(param_mod_spec) do
					if not param_mod_spec_key_is_builtin(k) then
						param_spec[k] = v
					end
				end
				params[param_mod] = param_spec
			end
		end
	end
end

--[==[
Return true if `k`, a key in an item, refers to a property of the item (is not one of the specially stored values).
Note that `lang` and `sc` are considered properties of the item, although `lang` is set when there's a language
prefix and both `lang` and `sc` may be set from default values specified in the `data` structure passed into
`parse_list_with_inline_modifiers_and_separate_params()` and `parse_term_with_inline_modifiers_and_separate_params()`.
If you don't want these treated as property keys, you need to check for them yourself.
]==]
function export.item_key_is_property(k)
	return k ~= "term" and k ~= "termlang" and k ~= "termlangs" and k ~= "itemno" and k ~= "orig_index" and
		k ~= "separator"
end

-- Fetch the argument in `args` corresponding to `index_or_value`, which may be a string of the form "foo.default"
-- (requesting the value of `args["foo"].default`); a string or number (requesting the value at that key); a function of
-- one argument (`args`), which returns the argument value; or the value itself. Return the resulting value and the
-- parameter in `args` that the value came from, or nil if unknown (i.e. a function or direct value was specified).
local function fetch_argument(args, index_or_value)
	if type(index_or_value) == "string" then
		if index_or_value:sub(-8) == ".default" then
			local index_without_default = index_or_value:sub(1, -9)
			local arg_obj = fetch_argument(args, index_without_default)
			if type(arg_obj) ~= "table" then
				internal_error(("Requested that the '.default' key of argument `%s` be fetched, but argument value is undefined or not a table"):
					format(index_without_default), arg_obj)
			end
			return arg_obj.default, index_without_default
		end
		if index_or_value:match("^%d+$") then
			index_or_value = tonumber(index_or_value)
		end
		return args[index_or_value], index_or_value
	elseif type(index_or_value) == "number" then
		return args[index_or_value], index_or_value
	elseif type(index_or_value) == "function" then
		return index_or_value(args), nil
	else
		return index_or_value, nil
	end
end

function export.generate_obj_maybe_parsing_lang_prefix(data)
	local term = data.term
	local term_dest = data.term_dest or "term"
	local termobj = data.termobj or {}

	-- Check for "special continuation" such as 'etc.'. 
	if data.special_continuations and data.special_continuations[term] then
		local is_continuation = data.recognize_continuations_everywhere
		if not is_continuation and data.separated_groups and data.group_index and
			#data.separated_groups == data.group_index then
			is_continuation = true
		end
		if is_continuation then
			termobj[term_dest] = nil
			termobj.alt = data.special_continuations[term]
			termobj.is_continuation = true
			termobj.lang = require(languages_module).getByCode("en")
			return
		end
	end

	if data.parse_lang_prefix and term:find(":") then
		local actual_term, termlangs = parse_term_with_lang {
			term = term,
			parse_err = data.parse_err,
			paramname = data.paramname,
			allow_bad = data.allow_bad_lang_prefix,
			allow_multiple = data.allow_multiple_lang_prefixes,
			lang_cache = data.lang_cache,
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

-- Subfunction of parse_list_with_inline_modifiers_and_separate_params() and
-- parse_term_with_inline_modifiers_and_separate_params(), validating certain argument-related fields that are shared
-- among the two functions.
local function validate_argument_related_fields(data)
	if not data.termarg then
		internal_error("`data.termarg` must be given, indicating which argument contains the terms to be parsed", data)
	end
	if not data.param_mods then
		internal_error("`data.param_mods` must be given, indicating the allowed inline modifiers and separate " ..
			"parameters to copy", data)
	end
	local subitem_param_handling = data.subitem_param_handling or "only"
	if subitem_param_handling ~= "only" and subitem_param_handling ~= "first" and subitem_param_handling ~= "last" then
		internal_error("Unrecognized value for `data.subitem_param_handling`, should be 'first', 'last' or 'only'",
			subitem_param_handling)
	end
	if data.raw_args then
		if data.processed_args then
			internal_error("Only one of `data.raw_args` and `data.processed_args` can be specified", data)
		end
		if not data.params then
			internal_error("When `data.raw_args` is specified, so must `data.params`, so that the raw arguments " ..
				"can be parsed", data)
		end
		if data.params[data.termarg] == nil then
			internal_error("There must be a spec in `data.params` corresponding to `data.termarg`", data)
		end
	else
		if not data.processed_args then
			internal_error("Either `data.raw_args` or `data.processed_args` must be specified", data)
		end
		if data.params then
			internal_error("When `data.processed_args` is specified, `data.params` should not be specified", data)
		end
	end
end

local function argval_missing(val)
	return val == nil or type(val) == "table" and next(val) == nil
end

-- Subfunction of parse_list_with_inline_modifiers_and_separate_params() and
-- parse_term_with_inline_modifiers_and_separate_params(). After parsing inline modifiers, copy the separate parameters
-- to the generated object (or to the appropriate subobject if there are multiple). `data` contains the following
-- fields:
--
-- `args`: The separate-parameter argument structure.
-- `param_mods`: The structure describing the inline modifiers.
-- `itemno`: The logical item number of the term being processed, or nil if there's only a single term.
-- `termobj`: The object to store the inline modifiers into. If there are subitems, they are in the `terms` field;
--     otherwise the properties are stored directly into `termobj`.
-- `has_subitems`: True if there are subitems.
-- `lang`: Language object to store into all items.
-- `sc`: Script object to store into all items, or nil.
-- `subitem_param_handling`: "only", "first" or "last", indicating what to do if there are multiple subitems.
-- `allow_conflicting_inline_mods_and_separate_params`: If true, specifying a value for both an inline modifier and
--     corresponding separate parameter is allowed, and the inline modifier takes precedence. Otherwise, an error
--     occurs.
-- `postprocess_termobj`: Optional function called on all items at the end, to do any postprocessing. Called with one
--     argument, the object to postprocess.
local function copy_separate_params_to_termobj_and_postprocess(data)
	local args, param_mods, itemno, termobj = data.args, data.param_mods, data.itemno, data.termobj

	local function set_lang_and_sc(termobj)
		-- Set these after parsing inline modifiers, not in generate_obj(), otherwise we'll get an error in
		-- parse_inline_modifiers() if we try to use <lang:...> or <sc:...> as inline modifiers.
		termobj.lang = termobj.lang or data.lang
		termobj.sc = termobj.sc or data.sc
	end

	local function fetch_separate_param(args, paramkey, itemno)
		local argval = args[paramkey]
		-- Careful with argument values that may be `false`.
		if argval and itemno then
			argval = argval[itemno]
		end
		return argval
	end

	-- Copy separate parameters to a given object.
	local function copy_separate_params_to_termobj(fetch_destobj)
		for param_mod, param_mod_spec in pairs(param_mods) do
			local dest = param_mod_spec.item_dest or param_mod
			-- Don't do anything with the `sc` param, which will get overwritten below; we don't
			-- want it to cause an error if there are multiple subitems.
			if dest ~= "sc" then
				local argval = fetch_separate_param(args, param_mod, itemno)
				if not argval_missing(argval) then
					local destobj = fetch_destobj(param_mod, dest)
					-- Don't overwrite a value already set by an inline modifier.
					if argval_missing(destobj[dest]) then
						destobj[dest] = argval
					elseif not data.allow_conflicting_inline_mods_and_separate_params then
						error(("Can't specify a value for separate parameter %s%s= because there is " ..
							"already an inline modifier <%s:...> specifying a value for the term"):format(
								param_mod, itemno or "", param_mod))
					end
				end
			end
		end
	end

	if data.has_subitems then
		-- If there are any separate indexed parameters, we need to copy them to the first, last or only
		-- subitem, depending on the value of `data.subitem_param_handling` (which defaults to 'only',
		-- meaning it's an error if there are multiple subitems). Do this before calling
		-- postprocess_termobj() because the latter sets .lang and .sc and we want the user to be able to
		-- set separate langN= and scN= parameters.

		-- If there was no term, `termobj.terms` will not exist; make it exist to make the callers' lives easier.
		if not termobj.terms then
			termobj.terms = {}
		end

		-- Compute whether any of the separate indexed params exist for this index.
		local any_param_at_index
		for param_mod, param_mod_spec in pairs(param_mods) do
			local argval = fetch_separate_param(args, param_mod, itemno)
			if not argval_missing(argval) then
				any_param_at_index = true
				break
			end
		end

		-- If there was no term, but there's a separate parameter, we need to create an empty subitem.
		if any_param_at_index and not termobj.terms[1] then
			termobj.terms[1] = {}
		end
		local function fetch_destobj(param_mod, dest)
			if data.subitem_param_handling == "only" and termobj.terms[2] then
				error(("Can't specify a value for separate parameter %s%s= because there are " ..
					"multiple subitems (%s) in the term; use an inline modifier"):format(
						param_mod, itemno or "", #termobj.terms))
			end
			local termind
			-- q/a/l need to go at the beginning and qq/aa/ll/refs at the end, regardless; otherwise, respect
			-- `data.subitem_param_handling`.
			if dest == "q" or dest == "a" or dest == "l" then
				termind = 1
			elseif dest == "qq" or dest == "aa" or dest == "ll" or dest == "refs" then
				termind = #termobj.terms
			elseif data.subitem_param_handling == "only" or data.subitem_param_handling == "first" then
				termind = 1
			else
				termind = #termobj.terms
			end
			return termobj.terms[termind]
		end

		copy_separate_params_to_termobj(fetch_destobj)
		for _, subitem in ipairs(termobj.terms) do
			set_lang_and_sc(subitem)
			if data.postprocess_termobj then
				data.postprocess_termobj(subitem)
			end
		end
	else
		-- Copy all the parsed term-specific parameters into `termobj`.
		copy_separate_params_to_termobj(function(param_mod, dest) return termobj end)
		set_lang_and_sc(termobj)
		if data.postprocess_termobj then
			data.postprocess_termobj(termobj)
		end
	end
end

--[==[
Parse a list of terms, each of which may have properties specified using inline modifiers or separate parameters. This
function is intended for parsing the arguments of templates like {{tl|syn}}, {{tl|ant}} and related ''*nym'' templates;
alternative-form templates {{tl|alt}}/{{tl|alter}}; affix templates like {{tl|af}}/{{tl|affix}},
{{tl|com}}/{{tl|compound}}, etc.; affix usex templates like {{tl|afex}}/{{tl|affixusex}}; name templates like
{{tl|name translit}}; column templates like {{tl|col}}; pronunciation templates like {{tl|rhyme}}/{{tl|rhymes}} and
{{tl|hmp}}/{{tl|homophones}}; etc. In these templates there are one or more terms specified using numeric parameters, and
associated separate parameters specifying per-term properties such as {{para|t1}}, {{para|t2}}, {{para|t3}}, ... for the
gloss of the first, second, third, ... term respectively. All such properties can also be specified through inline
modifiers attached directly to each term (`<t:...>`, `<pos:...>`, etc.). Normally it is an error if both an inline
modifier and separate parameter for the same value are given, but this can be overridden (in which case inline modifiers
take precedence over separate parameters when both occur).

For an example of a typical workflow involving this function, see the comment at the top of this file.

Some notable properties of this function:
# Processing of the raw frame parent args using `process()` in [[Module:parameters]] can occur either inside of this
  function (the usual workflow) or outside of this function (for more complex cases). In the former case the raw parent
  args are passed in along with a partially built `params` structure of the sort required by [[Module:parameters]],
  containing only the term list itself along with any other parameters that are '''not''' term properties (such as
  a language code in {{para|1}} and boolean flags like {{para|nocat}}, {{para|nocap}}, etc.). This structure is
  ''augmented'' with list parameters, one for each per-term property, and [[Module:parameters]] is invoked. In the
  latter case where raw argument processing is done by the caller, they must build the partial `params` structure;
  augment it themselves using `augment_params_with_modifiers()`; call [[Module:parameters]] themselves; and pass in the
  processed arguments. In both cases, the return value of this function contains two values, a list of objects, one per
  term, specifying the term and all properties; and the processed arguments structure, so that the non-term-property
  arguments can be processed as appropriate.
# Optionally, each term can consist of a number of ''subitems'' separated by delimiters (usually a comma, but the
  possible delimiter or delimiters are controllable). Each subitem can have its own inline modifiers. This functionality
  is used, for example, by {{tl|col}} and variants, which allow each row to have comma-separated or tilde-separated
  subitems. When this feature is invoked, the format of the per-term object changes; instead of directly being an object
  describing the term and its properties, it is an object with a `terms` field containing a list of per-subitem objects
  along with other top-level fields describing per-term properties. By default, if there are separate parameters
  specified along with multiple subitems, an error occurs, but this is controllable; currently, you can request that the
  parameters be assigned to the first or last subitem.
# By default, special ''separator'' arguments may be present, mixed in among regular term arguments. Examples of such
  separator arguments are (by default; this can be overridden) a bare semicolon, specifying that the terms on either
  side should be separated by a semicolon instead of a comma (indicating a higher-level grouping); a bare tilde,
  replacing the comma separator with a tilde (indicating that the terms on either side are alternants); and a bare
  underscore, replacing the comma separator with a space. Separator arguments are ignored when numbering the separate
  parameters. You disable the separator argument handling entirely if it doesn't make sense to have this (e.g. in
  {{tl|af}}/{{tl|affix}}, where the separator is always a {{cd|+}} sign).

`data` is an object containing several possible fields.

1. Fields that are required or recommended (usually related to argument processing):
* `raw_args` ('''required''' unless `processed_args` is specified): The raw arguments, normally fetched from
  {frame:getParent().args}. They are parsed using `process()` in [[Module:parameters]]. Most callers pass in raw
  arguments.
* `processed_args`: The object of parsed arguments returned by `process()` in [[Module:parameters]]. One (but not both)
  of `raw_args` and `processed_args` must be set.
* `param_mods` ('''required'''): A structure describing the possible inline modifiers and their properties. See the
  introductory comment above. Most often, this is generated using `construct_param_mods()` rather than specified
  manually.
* `params` ('''required''' unless `processed_args` is specified): A structure describing the possible parameters,
  '''other than''' the ones that are separate-parameter equivalents of inline modifiers. This is automatically
  "augmented" with the separate-parameter equivalents of the inline modifiers described in `param_mods` prior to parsing
  the raw arguments with [[Module:parameters]]. '''WARNING:''' This structure is destructively modified, both by the
  "augmentation" process of adding separate-parameter equivalents of inline modifiers, and by the processing done by
  [[Module:parameters]] itself. (Nonetheless, substructures can safely be shared in this structure, and will be
  correctly handled.)
* `termarg` ('''required'''): The argument containing the first item with attached inline modifiers to be parsed.
  Usually a numeric value such as {1} or {2}.
* `track_module` ('''recommended'''): The name of the calling module, for use in adding tracking pages that are used
  internally to track pages containing template invocations with certain properties. Example properties tracked are
  missing items with corresponding properties as well as missing items without corresponding properties (which are
  skipped entirely). To find out the exact properties tracked and the name of the tracking pages, read the code.
* `lang` ('''recommended'''): The language object for the language of the items, or the name of the argument to fetch
  the object from. It is not strictly necessary to specify this, as this function only initializes items based on inline
  modifiers and separate arguments and doesn't actually format the resulting items. However, if specified, it is used
  for certain purposes:
  *# It specifies the default for the `lang` property of returned objects if not otherwise set (e.g. by a language
     prefix).
  *# It is used to initialize an internal cache for speeding up language-code parsing (primarily useful if the same
     language code may appear in several items, such as with {{tl|col}} and related templates).
  The value of `lang` can be any of the following:
  * If a string of the form "foo.default", it is assumed to be requesting the value of `args["foo"].default`.
  * Otherwise, if a string or number, it is assumed to be requesting the value of `args` at that key. Note that if the
    string is in the form of a number (e.g. "3"), it is normalized to a number prior to fetching (this also happens with
	a spec like "2.default").
  * Otherwise, if a function, it is assumed to be a function to return the argument value given `args`, which is passed
    to the function as its only argument.
  * Otherwise, it is used directly.
* `sc` ('''recommended'''): The script object for the items, or the name of the argument to fetch the object from. The
  possible values and their handling are the same as with `lang`. In general, as with `lang`, it is not strictly
  necessary to specify this. However, if specified, it is used to supply the default for the `sc` property of returned
  items if not otherwise set (e.g. by the {{para|sc<var>N</var>}} parameter or `<sc:...>` inline modifier). The most
  common value is {"sc.default"}.

2. Other argument-related fields:
* `process_args_before_parsing`: An optional function to apply further processing to the processed `args` structure
  returned by [[Module:parameters]], before parsing inline modifiers. This is passed one argument, the processed
  arguments. It should make modifications in-place.
* `term_dest`: The field to store the value of the item itself into, after inline modifiers and (if allowed) language
  prefixes are stripped off. Defaults to {"term"}.
* `pre_normalize_modifiers`: As in `parse_inline_modifiers()`.
* `allow_conflicting_inline_mods_and_separate_params`: If specified, don't throw an error if a value is specified for
  a given property using both an inline modifier and separate param; in this case, the inline modifier takes precedence.

3. Fields related to language prefixes:
* `parse_lang_prefix`: If true, allow and parse off a language code prefix attached to items followed by a colon, such
  as {la:minūtia} or {grc:[[σκῶρ|σκατός]]}. Etymology-only languages are allowed. Inline modifiers can be attached to
  such items. The exact syntax allowed is as specified in the `parse_term_with_lang()` function in
  [[Module:parse utilities]]. If `allow_multiple_lang_prefixes` is given, a {{cd|+}}-sign-separated list of language
  prefixes can be attached to an item. The resulting language object is stored into the `termlang` field, and also into
  the `lang` field (or in the case of `allow_multiple_lang_prefixes`, the list of language objects is stored into the
  `termlangs` field, and the first specified object is stored in the `lang` field).
* `allow_multiple_lang_prefixes`: If given in conjunction with `parse_lang_prefix`, multiple language code prefixes can
  be given, separated by a {{cd|+}} sign. See `parse_lang_prefix` above.
* `allow_bad_lang_prefix`: If given in conjunction with `parse_lang_prefix`, unrecognized language prefixes do not
  trigger an error, but are simply ignored (and not stripped off the item). Note that, regardless of whether this is
  given, prefixes before a colon do not trigger an error if they do not have the form of a language prefix or if a space
  follows the colon. It is not recommended that this be given because typos in language prefixes will not trigger an
  error and will tend to remain unfixed.

4. Fields related to custom/special separators:
* `disallow_custom_separators`: If specified, disallow specifying custom separators (semicolon, underscore, tilde; see
  the internal `default_special_separators` table, or the `special_separators` field) as an item value to override the
  default separator. By default, the previous separator of each item is considered to be an empty string (for the first
  item) and otherwise the value of the field `default_separator` (normally a comma + space), unless either the preceding
  item is one of the values listed in `special_separators`, such as a bare semicolon (which causes the following item's
  previous separator to be a semicolon + space) or an item has an embedded comma in it (which causes ''all'' items other
  than the first to have their previous separator be a semicolon + space). The previous separator of each item is set on
  the item's `separator` property. Bare semicolons and other separator arguments do not count when indexing items using
  separate parameters.
  For example, the following is correct:
  ** {{tl|template|lang|item 1|q1=qualifier 1|;|item 2|q2=qualifier 2}}
  If `disallow_custom_separators` is specified, however, the `separator` property is not set and separator arguments are
  not recognized.
* `default_separator`: Override the default separator (normally {", "}).
* `special_separators`: Table giving the special/custom separators that can be given, and how they should display. If
  not specified, the default in `default_special_separators` is used. This is a table mapping separator values (such as
  {"~"}) to the corresponding display string (such as {" ~ "}).

5. Fields related to multiple subitems in a given term:
* `splitchar`: A Lua pattern. If specified, each user-specified argument can consist of multiple delimiter-separated
  subitems, each of which may be followed by inline modifiers. In this case, each element in the returned list of items
  is no longer an object describing an item, but instead an object with a `terms` field, whose value is a list
  describing the subitems (whose format is the same as the normal format of an item in the top-level list when
  `splitchar` is not specified). Each subitem object will have a `delimiter` field holding the actual delimiter
  occurring before the subitem, which is useful in the case where `splitchar` matches multiple possible characters. In
  this case, it is possible to specify that a given modifier can only occur after the last subitem and effectively
  modifies the whole collection of subitems by setting `overall = true` on the modifier. In this case, the modifier's
  value will be stored in the top-level object (the object with the `terms` field specifying the subitems). Note that
  splitting on delimiters will not happen in certain protected sequences (by default comma+whitespace; see below). In
  addition, the algorithm to split on delimiters is sensitive to inline modifier syntax and will not be confused by
  delimiters inside of inline modifiers or inside of square brackets, which do not trigger splitting (whether or not
  contained within protected sequences).
* `escape_fun` and `unescape_fun`: As in `split_escaping()` and `split_alternating_runs_escaping()` in
  [[Module:parse utilities]]. They control the protected sequences that won't be split when `splitchar` is specified
  (see previous item). By default, `escape_comma_whitespace` and `unescape_comma_whitespace` are used, so that
  comma+whitespace sequences won't be split.
* `subitem_param_handling`: How to handle separate parameters that are specified in the presence of multiple subitems.
  The possible values are {"only"} (only allow separate parameters if there aren't any subitems, otherwise throw an
  error), {"first"} (store the separate parameters in the first subitem) and {"last"} (store the separate parameters
  in the last subitem). The default is {"only"}. As a special case, an {{para|scN}} separate parameter will be stored
  into all subitems.

6. Other fields:
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

Two values are returned, the list of items and the processed `args` structure. In each returned item, there will be one
field set for each specified property (either through inline modifiers or separate parameters). If subitems are not
allowed, each item directly has fields set on it for the specified properties. If subitems ''are'' allowed, each item
contains a `terms` field, which is a list of subitem objects, each of which has fields set on it for the specified
properties of that subitem. In addition, the following fields may be set on each item or subitem:
* `term`: The term portion of the item (minus inline modifiers and language prefixes). {nil} if no term was given.
* `orig_index`: The original index into the item in the items table returned by `process()` in [[Module:parameters]].
  This may differ from `itemno` if there are raw semiclons and `disallow_custom_separators` is not given.
* `itemno`: The logical index of the item. The index of separate parameters corresponds to this index. This may be
  different from `orig_index` in the presence of raw semicolons; see above.
* `termlang`: If there is a language prefix, the corresponding language object is stored here (only if
  `parse_lang_prefix` is set and `allow_multiple_lang_prefixes` is not set).
* `termlangs`: If there is are language prefixes and both `parse_lang_prefix` and `allow_multiple_lang_prefixes` are
   set, the list of corresponding language objects is stored here.
* `lang`: The language object of the item. This is set when either (a) there is a language prefix parsed off (if
  multiple prefixes are allowed, this corresponds to the first one); (b) the `lang` property is allowed and specified;
  (c) neither (a) nor (b) apply and the `lang` field of the overall `data` object is set, providing a default value.
* `sc`: The script object of the item. This is set when either (a) the `sc` property is allowed and specified; (b)
  `sc` isn't otherwise set and the `sc` field of the overall `data` object is set, providing a default value.
* `delimiter`: If subitems are allowed, this specifies the delimiter used prior to the given subitem (e.g. {","}).
In addition, regardless of whether subitems are allowed, the top-level item will have a `separator` field set if
`disallow_custom_separators` is not given, specifying the separator to display before the item.
]==]
function export.parse_list_with_inline_modifiers_and_separate_params(data)
	validate_argument_related_fields(data)
	local args
	if data.raw_args then
		local termarg_spec = data.params[data.termarg]
		if termarg_spec == true or not termarg_spec.list then
			internal_error("Term spec in `data.params` must have `list` set", termarg_spec)
		end
		if termarg_spec == true or not (termarg_spec.allow_holes or termarg_spec.disallow_holes) then
			internal_error("Term spec in `data.params` must have either `allow_holes` or `disallow_holes` set",
				termarg_spec)
		end
		export.augment_params_with_modifiers(data.params, data.param_mods)
		args = process_params(data.raw_args, data.params)
	else
		args = data.processed_args
	end

	if data.process_args_before_parsing then
		data.process_args_before_parsing(args)
	end

	-- Find the maximum index among any of the list parameters.
	local term_args = args[data.termarg]
	-- As a special case, the term args might not have a `maxindex` field because they might have
	-- been declared with `disallow_holes = true`, so fall back to the actual length of the list
	-- using the length function, since # can be unpredictable with arbitrary tables.
	local maxmaxindex = term_args.maxindex or length(term_args)
	for _, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	local special_separators = data.special_separators or export.default_special_separators
	local items = {}
	local lang_cache = data.lang_cache or {}
	local use_semicolon
	local lang = fetch_argument(args, data.lang)
	if lang then
		lang_cache[lang:getCode()] = lang
	end
	local sc = fetch_argument(args, data.sc)
	local term_dest = data.term_dest or "term"

	-- FIXME: this is vulnerable to abusive inputs like 1000000=.
	local itemno = 0
	for i = 1, maxmaxindex do
		local term = term_args[i]
		if data.disallow_custom_separators or not special_separators[term] then
			itemno = itemno + 1

			-- Compute whether any of the separate indexed params exist for this index.
			local any_param_at_index
			for param_mod, param_mod_spec in pairs(data.param_mods) do
				local argval = args[param_mod]
				-- Careful with argument values that may be `false`.
				if argval then
					argval = argval[itemno]
				end
				if not argval_missing(argval) then
					any_param_at_index = true
					break
				end
			end

			if data.stop_when and data.stop_when {
				term = term,
				-- FIXME, we should just pass in `any_param_at_index` directly.
				any_param_at_index = term ~= nil or any_param_at_index,
				orig_index = i,
				itemno = itemno,
				stored_itemno = #items + 1,
			} then
				break
			end

			-- If any of the params used for formatting this term is present, create a term and add it to the list.
			if not data.dont_skip_items and term == nil and not any_param_at_index then
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

				-- Add 1 because first term index starts at 2.
				local paramname = data.termarg + i - 1

				local function generate_obj(term, parse_err)
					return export.generate_obj_maybe_parsing_lang_prefix {
						term = term,
						termobj = data.splitchar and {} or termobj,
						term_dest = data.term_dest,
						paramname = paramname,
						parse_lang_prefix = data.parse_lang_prefix,
						parse_err = parse_err,
						allow_bad_lang_prefix = data.allow_bad_lang_prefix,
						allow_multiple_lang_prefixes = data.allow_multiple_lang_prefixes,
						lang_cache = lang_cache,
					}
				end

				if term then
					parse_inline_modifiers(term, {
						paramname = paramname,
						param_mods = data.param_mods,
						generate_obj = generate_obj,
						splitchar = data.splitchar,
						preserve_splitchar = true,
						escape_fun = data.escape_fun,
						unescape_fun = data.unescape_fun,
						outer_container = data.splitchar and termobj or nil,
						pre_normalize_modifiers = data.pre_normalize_modifiers,
					})
				end

				local function postprocess_termobj(termobj)
					if not data.disallow_custom_separators and not use_semicolon then
						if data.splitchar and termobj.delimiter == "," then
							use_semicolon = true
						else
							-- If the displayed term (from .term/etc. or .alt) has an embedded comma, use a semicolon to
							-- join the terms.
							local term_text = termobj[term_dest] or termobj.alt
							if term_text and term_text:find(",") then
								use_semicolon = true
							end
						end
					end
				end

				copy_separate_params_to_termobj_and_postprocess {
					args = args,
					param_mods = data.param_mods,
					itemno = itemno,
					termobj = termobj,
					has_subitems = not not data.splitchar,
					lang = lang,
					-- As a special case, if the caller defined a scN= separate param, set it on all subitems if there
					-- are multiple, falling back to the overall sc= param.
					sc = args.sc and args.sc[itemno] or sc,
					subitem_param_handling = data.subitem_param_handling,
					allow_conflicting_inline_mods_and_separate_params =
						data.allow_conflicting_inline_mods_and_separate_params,
					postprocess_termobj = postprocess_termobj,
				}
				table.insert(items, termobj)
			end
		end
	end

	if not data.disallow_custom_separators then
		-- Set the default separator of all those items for which a separator wasn't explicitly given to the default
		-- separator, defaulting to comma + space; but if any items have embedded commas, set the separator to
		-- semicolon + space.
		for _, item in ipairs(items) do
			if not item.separator then
				item.separator = use_semicolon and "; " or data.default_separator or ", "
			end
		end
	end

	return items, args
end


--[==[
Parse a single term that may have properties specified through inline modifiers or separate parameters. This differs
from `parse_list_with_inline_modifiers_and_separate_params()` in that the latter is for parsing a list of terms, each of
which may have properties specified through inline modifiers or separate parameters. Both functions optionally support
having multiple subitems in a single term. This function is used e.g. for form-of templates
({{tl|inflection of}}/{{tl|infl of}}, {{tl|form of}}, and specific templates such as
{{tl|alt form}}/{{tl|alternative form of}}, {{tl|abbr of}}/{{tl|abbreviation of}}, {{tl|clipping of}}, and many others);
for etymology templates ({{tl|bor}}/{{tl|borrowed}}, {{tl|der}}/{{tl|derived}}, etc. as well as `misc_variant` templates
like {{tl|ellipsis}}, {{tl|abbrev}}, {{tl|clipping}}, {{tl|reduplication}} and the like); and for other templates with
an argument structure similar to {{tl|l}} or {{tl|m}}. In these templates there is a term specified using a numeric
parameter and associated separate parameters specifying term properties such as {{para|t}} for the gloss or {{para|tr}}
for manual transliteration. All such properties can also be specified through inline modifiers attached directly to each
term (`<t:...>`, `<tr:...>`, etc.). Normally it is an error if both an inline modifier and separate parameter for the
same value are given, but this can be overridden (in which case inline modifiers take precedence over separate
parameters when both occur).

Some notable properties of this function:
# Processing of the raw frame parent args using `process()` in [[Module:parameters]] can occur either inside of this
  function (the usual workflow) or outside of this function (for more complex cases). In the former case the raw parent
  args are passed in along with a partially built `params` structure of the sort required by [[Module:parameters]],
  containing only the term list itself along with any other parameters that are '''not''' term properties (such as
  a language code in {{para|1}} and boolean flags like {{para|nocat}}, {{para|nocap}}, etc.). This structure is
  ''augmented'' with parameters, one for each per-term property, and [[Module:parameters]] is invoked. In the latter
  case where raw argument processing is done by the caller, they must build the partial `params` structure; augment it
  themselves using `augment_params_with_modifiers()`; call [[Module:parameters]] themselves; and pass in the processed
  arguments. In both cases, the return value of this function contains two values, an object specifying the term and all
  properties; and the processed arguments structure, so that the non-term-property arguments can be processed as
  appropriate.
# Optionally, the term can consist of a number of ''subitems'' separated by delimiters (usually a comma, but the
  possible delimiter or delimiters are controllable). Each subitem can have its own inline modifiers. This functionality
  is used, for example, by form-of templates. When this feature is invoked, the format of the term object changes;
  instead of directly being an object describing the term and its properties, it is an object with a `terms` field
  containing a list of per-subitem objects along with other top-level fields describing per-term properties. By default,
  if there are separate parameters specified along with multiple subitems, an error occurs, but this is controllable;
  currently, you can request that the parameters be assigned to the first or last subitem.

`data` is an object containing several possible fields.

1. Fields that are required or recommended (usually related to argument processing):
* `raw_args` ('''required''' unless `processed_args` is specified): The raw arguments, normally fetched from
  {frame:getParent().args}. They are parsed using `process()` in [[Module:parameters]]. Most callers pass in raw
  arguments.
* `processed_args`: The object of parsed arguments returned by `process()` in [[Module:parameters]]. One (but not both)
  of `raw_args` and `processed_args` must be set.
* `param_mods` ('''required'''): A structure describing the possible inline modifiers and their properties. See the
  introductory comment above. Most often, this is generated using `construct_param_mods()` rather than specified
  manually.
* `params` ('''required''' unless `processed_args` is specified): A structure describing the possible parameters,
  '''other than''' the ones that are separate-parameter equivalents of inline modifiers. This is automatically
  "augmented" with the separate-parameter equivalents of the inline modifiers described in `param_mods` prior to parsing
  the raw arguments with [[Module:parameters]]. '''WARNING:''' This structure is destructively modified, both by the
  "augmentation" process of adding separate-parameter equivalents of inline modifiers, and by the processing done by
  [[Module:parameters]] itself. (Nonetheless, substructures can safely be shared in this structure, and will be
  correctly handled.)
* `termarg` ('''required'''): The argument containing the item with attached inline modifiers to be parsed. Usually a
  numeric value such as {1} or {2}.
* `track_module` ('''recommended'''): The name of the calling module, for use in adding tracking pages that are used
  internally to track pages containing template invocations with certain properties.
* `lang` ('''recommended'''): The language object for the language of the item or subitems, or the name of the argument
  to fetch the object from. It is not strictly necessary to specify this, as this function only initializes items based
  on inline modifiers and separate arguments and doesn't actually format the resulting items. However, if specified, it
  is used for certain purposes:
  *# It specifies the default for the `lang` property of returned objects if not otherwise set (e.g. by a language
     prefix).
  *# It is used to initialize an internal cache for speeding up language-code parsing (primarily useful if the same
     language code may appear in several subitems).
  The value of `lang` can be any of the following:
  * If a string or number, it is assumed to be requesting the value of `args` at that key. Note that if the string is in
    the form of a number (e.g. "3"), it is normalized to a number prior to fetching.
  * Otherwise, if a function, it is assumed to be a function to return the argument value given `args`, which is passed
    to the function as its only argument.
  * Otherwise, it is used directly.
* `sc` ('''recommended'''): The script object for the item or subitems, or the name of the argument to fetch the object
  from. The possible values and their handling are the same as with `lang`. In general, as with `lang`, it is not
  strictly necessary to specify this. However, if specified, it is used to supply the default for the `sc` property of
  returned items if not otherwise set (e.g. by the {{para|sc}} parameter or `<sc:...>` inline modifier). The most common
  value is {"sc"}.
* `make_separate_g_into_list`: Set this to {true} if separate gender parameters exist are are specified using
  {{para|g}}, {{para|g2}}, etc. instead of using a single comma-separated {{para|g}} field.

2. Other argument-related fields:
* `adjust_params_before_arg_processing`: An optional function to further adjust the `params` structure prior to
  calling `process()` in [[Module:parameters]]. This should be used when there are mismatches between the format of a
  given property as an inline modifier and the corresponding property as a separate parameter (as with the {{para|g}}
  parameter and {{cd|<g:...>}} modifier, but this particular case is handled by the `make_separate_g_into_list` field).
* `process_args_before_parsing`: An optional function to apply further processing to the processed `args` structure
  returned by [[Module:parameters]], before parsing inline modifiers. This is passed one argument, the processed
  arguments. It should make modifications in-place.
* `term_dest`: The field to store the value of the item itself into, after inline modifiers and (if allowed) language
  prefixes are stripped off. Defaults to {"term"}.
* `pre_normalize_modifiers`: As in `parse_inline_modifiers()`.
* `allow_conflicting_inline_mods_and_separate_params`: If specified, don't throw an error if a value is specified for
  a given property using both an inline modifier and separate param; in this case, the inline modifier takes precedence.

3. Fields related to language prefixes:
* `parse_lang_prefix`: If true, allow and parse off a language code prefix attached to items followed by a colon, such
  as {la:minūtia} or {grc:[[σκῶρ|σκατός]]}. Etymology-only languages are allowed. Inline modifiers can be attached to
  such items. The exact syntax allowed is as specified in the `parse_term_with_lang()` function in
  [[Module:parse utilities]]. If `allow_multiple_lang_prefixes` is given, a {{cd|+}}-sign-separated list of language
  prefixes can be attached to an item. The resulting language object is stored into the `termlang` field, and also into
  the `lang` field (or in the case of `allow_multiple_lang_prefixes`, the list of language objects is stored into the
  `termlangs` field, and the first specified object is stored in the `lang` field).
* `allow_multiple_lang_prefixes`: If given in conjunction with `parse_lang_prefix`, multiple language code prefixes can
  be given, separated by a {{cd|+}} sign. See `parse_lang_prefix` above.
* `allow_bad_lang_prefix`: If given in conjunction with `parse_lang_prefix`, unrecognized language prefixes do not
  trigger an error, but are simply ignored (and not stripped off the item). Note that, regardless of whether this is
  given, prefixes before a colon do not trigger an error if they do not have the form of a language prefix or if a space
  follows the colon. It is not recommended that this be given because typos in language prefixes will not trigger an
  error and will tend to remain unfixed.

4. Fields related to multiple subitems in the term:
* `splitchar`: A Lua pattern. If specified, the user-specified argument can consist of multiple delimiter-separated
  subitems, each of which may be followed by inline modifiers. In this case, the first returned value is no longer an
  object describing the item, but instead an object with a `terms` field, whose value is a list describing the subitems
  (whose format is the same as the normal format of the item when `splitchar` is not specified). Each subitem object
  will have a `delimiter` field holding the actual delimiter occurring before the subitem, which is useful in the case
  where `splitchar` matches multiple possible characters. In this case, it is possible to specify that a given modifier
  can only occur after the last subitem and effectively modifies the whole collection of subitems by setting
  `overall = true` on the modifier. In this case, the modifier's value will be stored in the top-level object (the
  object with the `terms` field specifying the subitems). Note that splitting on delimiters will not happen in certain
  protected sequences (by default comma+whitespace; see below). In addition, the algorithm to split on delimiters is
  sensitive to inline modifier syntax and will not be confused by delimiters inside of inline modifiers or inside of
  square brackets, which do not trigger splitting (whether or not contained within protected sequences).
* `escape_fun` and `unescape_fun`: As in `split_escaping()` and `split_alternating_runs_escaping()` in
  [[Module:parse utilities]]. They control the protected sequences that won't be split when `splitchar` is specified
  (see previous item). By default, `escape_comma_whitespace` and `unescape_comma_whitespace` are used, so that
  comma+whitespace sequences won't be split.
* `subitem_param_handling`: How to handle separate parameters that are specified in the presence of multiple subitems.
  The possible values are {"only"} (only allow separate parameters if there aren't any subitems, otherwise throw an
  error), {"first"} (store the separate parameters in the first subitem) and {"last"} (store the separate parameters
  in the last subitem). The default is {"only"}. As a special case, an {{para|scN}} separate parameter will be stored
  into all subitems.

Two values are returned, an object describing the item (or subitems) and the processed `args` structure. In the returned
item, there will be one field set for each specified property (either through inline modifiers or separate parameters).
If subitems are not allowed, the item directly has fields set on it for the specified properties. If subitems ''are''
allowed, the item contains a `terms` field, which is a list of subitem objects, each of which has fields set on it for
the specified properties of that subitem. In addition, the following fields may be set on the item or each subitem:
* `term`: The term portion of the item (minus inline modifiers and language prefixes). {nil} if no term was given.
* `termlang`: If there is a language prefix, the corresponding language object is stored here (only if
  `parse_lang_prefix` is set and `allow_multiple_lang_prefixes` is not set).
* `termlangs`: If there is are language prefixes and both `parse_lang_prefix` and `allow_multiple_lang_prefixes` are
   set, the list of corresponding language objects is stored here.
* `lang`: The language object of the item. This is set when either (a) there is a language prefix parsed off (if
  multiple prefixes are allowed, this corresponds to the first one); (b) the `lang` property is allowed and specified;
  (c) neither (a) nor (b) apply and the `lang` field of the overall `data` object is set, providing a default value.
* `sc`: The script object of the item. This is set when either (a) the `sc` property is allowed and specified; (b)
  `sc` isn't otherwise set and the `sc` field of the overall `data` object is set, providing a default value.
* `delimiter`: If subitems are allowed, this specifies the delimiter used prior to the given subitem (e.g. {","}).
]==]
function export.parse_term_with_inline_modifiers_and_separate_params(data)
	validate_argument_related_fields(data)
	local args
	if data.raw_args then
		local termarg_spec = data.params[data.termarg]
		if type(termarg_spec) == "table" and termarg_spec.list then
			internal_error("Term spec in `data.params` must not have `list` set", termarg_spec)
		end
		export.augment_params_with_modifiers(data.params, data.param_mods, "always")
		if data.make_separate_g_into_list then
			-- HACK: g= is a list for compatibility, but sublist as an inline parameter.
			data.params.g = {list = true, item_dest = "genders"}
		end
		if data.adjust_params_before_arg_processing then
			data.adjust_params_before_arg_processing(data.params)
		end
		args = process_params(data.raw_args, data.params)
	else
		args = data.processed_args
	end

	if data.process_args_before_parsing then
		data.process_args_before_parsing(args)
	end

	local termarg = data.termarg
	local term = args[termarg]
	local lang = fetch_argument(args, data.lang)
	if lang and data.lang_cache then
		data.lang_cache[lang:getCode()] = lang
	end
	local sc = fetch_argument(args, data.sc)
	local term_dest = data.term_dest or "term"

	if not term then
		track("missing-term", data.track_module)
	end
	local termobj = {}

	local function generate_obj(term, parse_err)
		return export.generate_obj_maybe_parsing_lang_prefix {
			term = term,
			termobj = data.splitchar and {} or termobj,
			term_dest = data.term_dest,
			paramname = termarg,
			parse_lang_prefix = data.parse_lang_prefix,
			parse_err = parse_err,
			allow_bad_lang_prefix = data.allow_bad_lang_prefix,
			allow_multiple_lang_prefixes = data.allow_multiple_lang_prefixes,
			lang_cache = data.lang_cache,
		}
	end

	if term then
		parse_inline_modifiers(term, {
			paramname = paramname,
			param_mods = data.param_mods,
			generate_obj = generate_obj,
			splitchar = data.splitchar,
			preserve_splitchar = true,
			escape_fun = data.escape_fun,
			unescape_fun = data.unescape_fun,
			outer_container = data.splitchar and termobj or nil,
			pre_normalize_modifiers = data.pre_normalize_modifiers,
		})
	end

	copy_separate_params_to_termobj_and_postprocess {
		args = args,
		param_mods = data.param_mods,
		termobj = termobj,
		has_subitems = not not data.splitchar,
		lang = lang,
		sc = sc,
		subitem_param_handling = data.subitem_param_handling,
		allow_conflicting_inline_mods_and_separate_params = data.allow_conflicting_inline_mods_and_separate_params,
	}

	if data.splitchar and termobj.terms[2] then
		track("parse-term-multiple-subitems", data.track_module)
		track("parse-term-multiple-subitems")
	end

	return termobj, args
end


return export
