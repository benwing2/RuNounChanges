--[==[TODO:
* Change certain flag names, as some are misnomers:
	* Change `allow_holes` to `keep_holes`, because it's not the inverse of `disallow_holes`.
	* Change `allow_empty` to `keep_empty`, as it causes them to be kept as "" instead of deleted.
* Sort out all the internal error calls. Manual error(format()) calls are used when certain parameters shouldn't be dumped, so find a way to avoid that.
]==]

local export = {}

local debug_track_module = "Module:debug/track"
local families_module = "Module:families"
local function_module = "Module:fun"
local labels_module = "Module:labels"
local languages_module = "Module:languages"
local math_module = "Module:math"
local pages_module = "Module:pages"
local parse_utilities_module = "Module:parse utilities"
local references_module = "Module:references"
local scripts_module = "Module:scripts"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local wikimedia_languages_module = "Module:wikimedia languages"
local yesno_module = "Module:yesno"

local mw = mw
local mw_title = mw.title
local string = string
local table = table

local dump = mw.dumpObject
local find = string.find
local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local insert = table.insert
local ipairs = ipairs
local list_to_text = mw.text.listToText
local make_title = mw_title.makeTitle
local match = string.match
local max = math.max
local maxn = table.maxn
local new_title = mw_title.new
local next = next
local pairs = pairs
local pcall = pcall
local rawset = rawset
local require = require
local sort = table.sort
local sub = string.sub
local tonumber = tonumber
local traceback = debug.traceback
local type = type

local current_title_text, current_namespace -- Defined when needed.
local namespaces = mw.site.namespaces

--[==[
Loaders for functions in other modules, which overwrite themselves with the target function when called. This ensures modules are only loaded when needed, retains the speed/convenience of locally-declared pre-loaded functions, and has no overhead after the first call, since the target functions are called directly in any subsequent calls.]==]
local function debug_track(...)
	debug_track = require(debug_track_module)
	return debug_track(...)
end

local function decode_entities(...)
	decode_entities = require(string_utilities_module).decode_entities
	return decode_entities(...)
end

local function extend(...)
	extend = require(table_module).extend
	return extend(...)
end

local function get_family_by_code(...)
	get_family_by_code = require(families_module).getByCode
	return get_family_by_code(...)
end

local function get_family_by_name(...)
	get_family_by_name = require(families_module).getByCanonicalName
	return get_family_by_name(...)
end

local function get_language_by_code(...)
	get_language_by_code = require(languages_module).getByCode
	return get_language_by_code(...)
end

local function get_language_by_name(...)
	get_language_by_name = require(languages_module).getByCanonicalName
	return get_language_by_name(...)
end

local function get_script_by_code(...)
	get_script_by_code = require(scripts_module).getByCode
	return get_script_by_code(...)
end

local function get_script_by_name(...)
	get_script_by_name = require(scripts_module).getByCanonicalName
	return get_script_by_name(...)
end

local function get_wm_lang_by_code(...)
	get_wm_lang_by_code = require(wikimedia_languages_module).getByCode
	return get_wm_lang_by_code(...)
end

local function get_wm_lang_by_code_with_fallback(...)
	get_wm_lang_by_code_with_fallback = require(wikimedia_languages_module).getByCodeWithFallback
	return get_wm_lang_by_code_with_fallback(...)
end

local function gsplit(...)
	gsplit = require(string_utilities_module).gsplit
	return gsplit(...)
end

local function is_callable(...)
	is_callable = require(function_module).is_callable
	return is_callable(...)
end

local function is_finite_real_number(...)
	is_finite_real_number = require(math_module).is_finite_real_number
	return is_finite_real_number(...)
end

local function is_integer(...)
	is_integer = require(math_module).is_integer
	return is_integer(...)
end

local function is_internal_title(...)
	is_internal_title = require(pages_module).is_internal_title
	return is_internal_title(...)
end

local function is_positive_integer(...)
	is_positive_integer = require(math_module).is_positive_integer
	return is_positive_integer(...)
end

local function iterate_list(...)
	iterate_list = require(table_module).iterateList
	return iterate_list(...)
end

local function list_to_set(...)
	list_to_set = require(table_module).listToSet
	return list_to_set(...)
end

local function num_keys(...)
	num_keys = require(table_module).numKeys
	return num_keys(...)
end

local function parse_references(...)
	parse_references = require(references_module).parse_references
	return parse_references(...)
end

local function pattern_escape(...)
	pattern_escape = require(string_utilities_module).pattern_escape
	return pattern_escape(...)
end

local function php_trim(...)
	php_trim = require(string_utilities_module).php_trim
	return php_trim(...)
end

local function scribunto_param_key(...)
	scribunto_param_key = require(string_utilities_module).scribunto_param_key
	return scribunto_param_key(...)
end

local function sorted_pairs(...)
	sorted_pairs = require(table_module).sortedPairs
	return sorted_pairs(...)
end

local function split(...)
	split = require(string_utilities_module).split
	return split(...)
end

local function split_labels_on_comma(...)
	split_labels_on_comma = require(labels_module).split_labels_on_comma
	return split_labels_on_comma(...)
end

local function split_on_comma(...)
	split_on_comma = require(parse_utilities_module).split_on_comma
	return split_on_comma(...)
end

local function yesno(...)
	yesno = require(yesno_module)
	return yesno(...)
end

--[==[ intro:
This module is used to standardize template argument processing and checking. A typical workflow is as follows (based
on [[Module:translations]]):

{
	...
	local parent_args = frame:getParent().args

	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = true,
		[3] = {list = true},
		["alt"] = true,
		["id"] = true,
		["sc"] = {type = "script"},
		["tr"] = true,
		["ts"] = true,
		["lit"] = true,
	}

	local args = require("Module:parameters").process(parent_args, params)

	-- Do further processing of the parsed arguments in `args`.
	...
}

The `params` table should have the parameter names as the keys, and a (possibly empty) table of parameter tags as the
value. An empty table as the value merely states that the parameter exists, but should not receive any special
treatment; if desired, empty tables can be replaced with the value `true` as a perforamnce optimization.

Possible parameter tags are listed below:

; {required = true}
: The parameter is required; an error is shown if it is not present. The template's page itself is an exception; no
  error is shown there.
; {default =}
: Specifies a default input value for the parameter, if it is absent or empty. This will be processed as though it were
  the input instead, so (for example) {default = "und"} with the type {"language"} will return a language object for
  [[:Category:Undetermined language|Undetermined language]] if no language code is provided. When used on list
  parameters, this specifies a default value for the first item in the list only. Note that it is not possible to
  generate a default that depends on the value of other parameters. If used together with {required = true}, the default
  applies only to template pages (see the following entry), as a side effect of the fact that "required" parameters
  aren't actually required on template pages. This can be used to show an example of the template in action when the
  template page is visited; however, it is preferred to use `template_default` for this purpose, for clarity.
; {template_default =}
: Specifies a default input value for absent or empty parameters only on template pages. Template pages are any page in
  the template space (beginning with `Template:`) except for documentation pages (those ending in `.../documentation`).
  This can be used to provide an example value for a non-required parameter when the template page is visited, without
  interfering with other uses of the template. Both `template_default` and `default` can be specified for the same
  parameter. If this is done, `template_default` applies on template pages, and `default` on other pages. As an example,
  {{tl|cs-IPA}} uses the equivalent of {[1] = {default = "+", template_default = "příklad"}} to supply a default of
  {"+"} for mainspace and documentation pages (which tells the module to use the value of the {{para|pagename}}
  parameter, falling back to the actual pagename), but {"příklad"} (which means "example"), on [[Template:cs-IPA]].
; {alias_of =}
: Treat the parameter as an alias of another. When arguments are specified for this parameter, they will automatically
  be renamed and stored under the alias name. This allows for parameters with multiple alternative names, while still
  treating them as if they had only one name. The conversion-related properties of an aliased parameter (e.g. `type`,
  `set`, `convert`, `sublist`) are taken from the aliasee, and the corrresponding properties set on the alias itself
  are ignored; but other properties on the alias are taken from the alias's spec and not from the aliasee's spec. This
  means, for example, that if you create an alias of a list parameter, the alias must also specify the `list` property
  or it is not a list. (In such a case, a value specified for the alias goes into the first item of the aliasee's list.
  You cannot make a list alias of a non-list parameter; this causes an error to be thrown.) Similarly, if you specify
  `separate_no_index` on an aliasee but not on the alias, uses of the unindexed aliasee parameter are stored into the
  `.default` key, but uses of the unindexed alias are stored into the first numbered key of the aliasee's list.
  Aliases cannot be required, as this prevents the other name or names of the parameter from being used. Parameters
  that are aliases and required at the same time cause an error to be thrown.
; {allow_empty = true}
: If the argument is an empty string value, it is not converted to {nil}, but kept as-is. The use of `allow_empty` is
  disallowed if a type has been specified, and causes an error to be thrown.
; {no_trim = true}
: Spacing characters such as spaces and newlines at the beginning and end of a positional parameter are not removed.
  (MediaWiki itself automatically trims spaces and newlines at the edge of named parameters.) The use of `no_trim` is
  disallowed if a type has been specified, and causes an error to be thrown.
; {type =}
: Specifies what value type to convert the argument into. The default is to leave it as a text string. Alternatives are:
:; {type = "boolean"}
:: The value is treated as a boolean value, either true or false. No value, the empty string, and the strings {"0"},
   {"no"}, {"n"}, {"false"}, {"f"} and {"off"} are treated as {false}, all other values are considered {true}.
:; {type = "number"}
:: The value is converted into a number, and throws an error if the value is not parsable as a number. Input values may
   be signed (`+` or `-`), and may contain decimal points and leading zeroes. If {allow_hex = true}, then hexadecimal
   values in the form {"0x100"} may optionally be used instead, which otherwise have the same syntax restrictions
   (including signs, decimal digits, and leading zeroes after {"0x"}). Hexadecimal inputs are not case-sensitive. Lua's
   special number values (`inf` and `nan`) are not possible inputs.
:; {type = "language"}
:: The value is interpreted as a full or [[Wiktionary:Languages#Etymology-only languages|etymology-only language]] code
   language code (or name, if {method = "name"}) and converted into the corresponding object (see [[Module:languages]]).
   If the code or name is invalid, then an error is thrown. The additional setting {family = true} can be given to allow
   [[Wiktionary:Language families|language family codes]] to be considered valid and the corresponding object returned.
   Note that to distinguish an etymology-only language object from a full language object, use
   {object:hasType("language", "etymology-only")}.
:; {type = "full language"}
:: The value is interpreted as a full language code (or name, if {method = "name"}) and converted into the corresponding
   object (see [[Module:languages]]). If the code or name is invalid, then an error is thrown. Etymology-only languages
   are not allowed. The additional setting {family = true} can be given to allow
   [[Wiktionary:Language families|language family codes]] to be considered valid and the corresponding object returned.
:; {type = "Wikimedia language"}
:: The value is interpreted as a code and converted into a Wikimedia language object. If the code is invalid, then an
   error is thrown. If {fallback = true} is specified, conventional language codes which are different from their
   Wikimedia equivalent will also be accepted as a fallback.
:; {type = "family"}
:: The value is interpreted as a language family code (or name, if {method = "name"}) and converted into the
   corresponding object (see [[Module:families]]). If the code or name is invalid, then an error is thrown.
:; {type = "script"}
:: The value is interpreted as a script code (or name, if {method = "name"}) and converted into the corresponding object
   (see [[Module:scripts]]). If the code or name is invalid, then an error is thrown.
:; {type = "title"}
:: The value is interpreted as a page title and converted into the corresponding object (see the [[mw:Extension:Scribunto/Lua_reference_manual#Title_library|Title library]]). If the page title is invalid, then an error is thrown; by default, external titles (i.e. those on other wikis) are not treated as valid. Options are:
::; {namespace = n}
::: The default namespace, where {n} is a namespace number; this is treated as {0} (the mainspace) if not specified.
::; {allow_external = true}
::: External titles are treated as valid.
::; {prefix = "namespace override"} (default)
::: The default namespace prefix will be prefixed to the value is already prefixed by a namespace prefix. For instance, the input {"Foo"} with namespace {10} returns {"Template:Foo"}, {"Wiktionary:Foo"} returns {"Wiktionary:Foo"}, and {"Template:Foo"} returns {"Template:Foo"}. Interwiki prefixes cannot act as overrides, however: the input {"fr:Foo"} returns {"Template:fr:Foo"}.
::; {prefix = "force"}
::: The default namespace prefix will be prefixed unconditionally, even if the value already appears to be prefixed. This is the way that {{tl|#invoke:}} works when calling modules from the module namespace ({828}): the input {"Foo"} returns {"Module:Foo"}, {"Wiktionary:Foo"} returns {"Module:Wiktionary:Foo"}, and {"Module:Foo"} returns {"Module:Module:Foo"}.
::; {prefix = "full override"}
::: The same as {prefix = "namespace override"}, except that interwiki prefixes can also act as overrides. For instance, {"el:All topics"} with namespace {14} returns {"el:Category:All topics"}. Due to the limitations of MediaWiki, only the first prefix in the value may act as an override, so the namespace cannot be overridden if the first prefix is an interwiki prefix: e.g. {"el:Template:All topics"} with namespace {14} returns {"el:Category:Template:All topics"}.
:; {type = "parameter"}
:: The value is interpreted as the name of a parameter, and will be normalized using the method that Scribunto uses when constructing a {frame.args} table of arguments. This means that integers will be converted to numbers, but all other arguments will remain as strings (e.g. {"1"} will be normalized to {1}, but {"foo"} and {"1.5"} will remain unchanged). Note that Scribunto also trims parmeter names, following the same trimming method that this module applies by default to all parameter types.
:: This type is useful when one set of input arguments is used to construct a {params} table for use in a subsequent {export.process()} call with another set of input arguments; for instance, the set of valid parameters for a template might be defined as {{tl|#invoke:[some module]|args=}} in the template, where {args} is a sublist of valid parameters for the template.
:; {type = "qualifier"}
:: The value is interpreted as a qualifier and converted into the correct format for passing into `format_qualifiers()`
   in [[Module:qualifier]] (which currently just means converting it to a one-item list).
:; {type = "labels"}
:: The value is interpreted as a comma-separated list of labels and converted into the correct format for passing into
   `show_labels()` in [[Module:labels]] (which is currently a list of strings). Splitting is done on commas not followed
   by whitespace, except that commas inside of double angle brackets do not count even if not followed by whitespace.
   This type should be used by for normal labels (typically specified using {{para|l}} or {{para|ll}}) and accent
   qualifiers (typically specified using {{para|a}} and {{para|aa}}).
:; {type = "references"}
:: The value is interpreted as one or more references, in the format prescribed by `parse_references()` in
   [[Module:references]], and converted into a list of objects of the form accepted by `format_references()` in the same
   module. If a syntax error is found in the reference format, an error is thrown.
:; {type = function(val) ... end}
:: `type` may be set to a function (or callable table), which must take the argument value as its sole argument, and must
   output one of the other recognized types. This is particularly useful for lists (see below), where certain values need
   to be interpreted differently to others.
; {list =}
: Treat the parameter as a list of values, each having its own parameter name, rather than a single value. The
  parameters will have a number at the end, except optionally for the first (but see also {require_index = true}). For
  example, {list = true} on a parameter named "head" will include the parameters {{para|head}} (or {{para|head1}}),
  {{para|head2}}, {{para|head3}} and so on. If the parameter name is a number, another number doesn't get appended, but
  the counting simply continues, e.g. for parameter {3} the sequence is {{para|3}}, {{para|4}}, {{para|5}} etc. List
  parameters are returned as numbered lists, so for a template that is given the parameters `|head=a|head2=b|head3=c`,
  the processed value of the parameter {"head"} will be { { "a", "b", "c" }}}.
: The value for {list =} can also be a string. This tells the module that parameters other than the first should have a
  different name, which is useful when the first parameter in a list is a number, but the remainder is named. An example
  would be for genders: {list = "g"} on a parameter named {1} would have parameters {{para|1}}, {{para|g2}}, {{para|g3}}
  etc.
: If the number is not located at the end, it can be specified by putting {"\1"} at the number position. For example,
  parameters {{para|f1accel}}, {{para|f2accel}}, ... can be captured by using the parameter name {"f\1accel"}, as is
  done in [[Module:headword/templates]].
; {set =}
: Require that the value of the parameter be one of the specified list of values (or omitted, if {required = true} isn't
  given). The values in the specified list should be strings corresponding to the raw parameter values except when
  {type = "number"}, in which case they should be numbers. The use of `set` is disallowed if {type = "boolean"} and
  causes an error to be thrown.
; {sublist =}
: The value of the parameter is a delimiter-separated list of individual raw values. The resulting field in `args` will
  be a Lua list (i.e. a table with numeric indices) of the converted values. If {sublist = true} is given, the values
  will be split on commas (possibly with whitespace on one or both sides of the comma, which is ignored). If
  {sublist = "comma without whitespace"} is given, the values will be split on commas which are not followed by whitespace,
  and which aren't preceded by an escaping backslash. Otherwise, the value of `sublist` should be either a Lua pattern
  specifying the delimiter(s) to split on or a function (or callable table) to do the splitting, which is passed two values
  (the value to split and a function to signal an error) and should return a list of the split values.
; {convert =}
: If given, this specifies a function (or callable table) to convert the raw parameter value into the Lua object used
  during further processing. The function is passed two arguments, the raw parameter value itself and a function used to
  signal an error during parsing or conversion, and should return one value, the converted parameter. The error-signaling
  function contains the name and raw value of the parameter embedded into the message it generates, so these do not need to
  specified in the message passed into it. If `type` is specified in conjunction with `convert`, the processing by
  `type` happens first. If `sublist` is given in conjunction with `convert`, the raw parameter value will be split
  appropriately and `convert` called on each resulting item.
; {allow_hex = true}
: When used in conjunction with {type = "number"}, allows hexadecimal numbers as inputs, in the format {"0x100"} (which is
  not case-sensitive).
; {family = true}
: When used in conjunction with {type = "language"}, allows [[Wiktionary:Language families|language family codes]] to be
  returned. To check if a given object refers to a language family, use {object:hasType("family")}.
; {method = "name"}
: When used in conjunction with {type = "language"}, {type = "family"} or {type = "script"}, checks for and parses a
  language, family or script name instead of a code.
; {allow_holes = true}
: This is used in conjunction with list-type parameters. By default, the values are tightly packed in the resulting
  list. This means that if, for example, an entry specified `head=a|head3=c` but not {{para|head2}}, the returned list
  will be { {"a", "c"}}}, with the values stored at the indices {1} and {2}, not {1} and {3}. If it is desirable to keep
  the numbering intact, for example if the numbers of several list parameters correlate with each other (like those of
  {{tl|affix}}), then this tag should be specified.
: If {allow_holes = true} is given, there may be {nil} values in between two real values, which makes many of Lua's
  table processing functions no longer work, like {#} or {ipairs()}. To remedy this, the resulting table will contain an
  additional named value, `maxindex`, which tells you the highest numeric index that is present in the table. In the
  example above, the resulting table will now be { { "a", nil, "c", maxindex = 3}}}. That way, you can iterate over the
  values from {1} to `maxindex`, while skipping {nil} values in between.
; {disallow_holes = true}
: This is used in conjunction with list-type parameters. As mentioned above, normally if there is a hole in the source
  arguments, e.g. `head=a|head3=c` but not {{para|head2}}, it will be removed in the returned list. If
  {disallow_holes = true} is specified, however, an error is thrown in such a case. This should be used whenever there
  are multiple list-type parameters that need to line up (e.g. both {{para|head}} and {{para|tr}} are available and
  {{para|head3}} lines up with {{para|tr3}}), unless {allow_holes = true} is given and you are prepared to handle the
  holes in the returned lists.
; {disallow_missing = true}
: This is similar to {disallow_holes = true}, but an error will not be thrown if an argument is blank, rather than
  completely missing. This may be used to tolerate intermediate blank numerical parameters, which sometimes occur in list
  templates. For instance, `head=a|head2=|head3=c` will not throw an error, but `head=a|head3=c` will.
; {require_index = true}
: This is used in conjunction with list-type parameters. By default, the first parameter can have its index omitted.
  For example, a list parameter named `head` can have its first parameter specified as either {{para|head}} or
  {{para|head1}}. If {require_index = true} is specified, however, only {{para|head1}} is recognized, and {{para|head}}
  will be treated as an unknown parameter. {{tl|affixusex}} (and variants {{tl|suffixusex}}, {{tl|prefixusex}}) use
  this, for example, on all list parameters.
; {separate_no_index = true}
: This is used to distinguish between {{para|head}} and {{para|head1}} as different parameters. For example, in
  {{tl|affixusex}}, to distinguish between {{para|sc}} (a script code for all elements in the usex's language) and
  {{para|sc1}} (the script code of the first element, used when the first element is prefixed with a language code to
  indicate that it is in a different language). When this is used, the resulting table will contain an additional named
  value, `default`, which contains the value for the indexless argument.
; {demo = true}
: This is used as a way to ensure that the parameter is only enabled on the template's own page (and its documentation page), and in the User: namespace; otherwise, it will be treated as an unknown parameter. This should only be used if special settings are required to showcase a template in its documentation (e.g. adjusting the pagename or disabling categorization). In most cases, it should be possible to do this without using demo parameters, but they may be required if a template/documentation page also contains real uses of the same template as well (e.g. {{tl|shortcut}}), as a way to distinguish them.
]==]

-- Returns true if the current page is a template or module containing the current {{#invoke}}.
-- If the include_documentation argument is given, also returns true if the current page is either page's docuemntation page.
local own_page, own_page_or_documentation
local function is_own_page(include_documentation)
	if own_page == nil then
		if current_namespace == nil then
			local current_title = mw_title.getCurrentTitle()
			current_title_text, current_namespace = current_title.prefixedText, current_title.namespace
		end
		local frame = current_namespace == 828 and mw.getCurrentFrame() or
			current_namespace == 10 and mw.getCurrentFrame():getParent()
		if frame then
			local frame_title_text = frame:getTitle()
			own_page = current_title_text == frame_title_text
			own_page_or_documentation = own_page or current_title_text == frame_title_text .. "/documentation"
		else
			own_page, own_page_or_documentation = false, false
		end
	end
	return include_documentation and own_page_or_documentation or own_page
end

local function track(page)
	local pages, current = {"parameters/" .. page}
	-- Check through the traceback to get the calling module and function.
	for mod, func in gmatch(traceback(), "%f[^%z\n]\tModule:(.-):%d+: in function '(.-)'%f[%z\n]") do
		if current == nil then
			current = mod -- Name of this module.
		elseif mod ~= current then
			insert(pages, "parameters/" .. page .. "/" .. mod)
			-- FIXME: if the calling function is the one called by #invoke:, traceback calls it "chunk" instead of its actual name.
			insert(pages, "parameters/" .. page .. "/" .. mod .. "/" .. func)
			break
		end
	end
	debug_track(pages)
end

-------------------------------------- Some helper functions -----------------------------

-- Convert a list in `list` to a string, separating the final element from the preceding one(s) by `conjunction`. If
-- `dump_vals` is given, pass all values in `list` through mw.dumpObject() (WARNING: this destructively modifies
-- `list`). This is similar to serialCommaJoin() in [[Module:table]] when used with the `dontTag = true` option, but
-- internally uses mw.text.listToText().
local function concat_list(list, conjunction, dump_vals)
	if dump_vals then
		for k, v in pairs(list) do
			list[k] = dump(v)
		end
	end
	return list_to_text(list, nil, conjunction)
end

-- Split an argument on comma, but not comma followed by whitespace.
local function split_on_comma_without_whitespace(val)
	if find(val, "\\", nil, true) or match(val, ",%s") then
		return split_on_comma(val)
	end
	return split(val, ",")
end

-- A helper function for use with generating error-signaling functions in the presence of raw value conversion. Format a
-- message `msg`, including the processed value `processed` if it is different from the raw value `rawval`; otherwise,
-- just return `msg`.
local function msg_with_processed(msg, rawval, processed)
	if rawval == processed then
		return msg
	end
	local processed_type = type(processed)
	return format("%s (processed value %s)",
		msg, (processed_type == "string" or processed_type == "number") and processed or dump(processed)
	)
end

-------------------------------------- Error handling -----------------------------

local function process_error(fmt, ...)
	local args = {...}
	for i, val in ipairs(args) do
		args[i] = dump(val)
	end
	if type(fmt) == "table" then
		-- hacky signal that we're called from internal_process_error(), and not to omit stack frames
		return error(format(fmt[1], unpack(args)))
	end
	return error(format(fmt, unpack(args)), 3)
end

local function internal_process_error(fmt, ...)
	process_error({"Internal error in `params` table: " .. fmt}, ...)
end

-- Check that a parameter or argument is in the form form Scribunto normalizes input argument keys into (e.g. 1 not "1", "foo" not " foo "). Otherwise, it won't be possible to normalize inputs in the expected way. Unless is_argument is set, also check that the name only contains one placeholder at most, and that strings don't resolve to numeric keys once the placeholder has been substituted.
local function validate_name(name, desc, extra_name, is_argument)
	local normalized = scribunto_param_key(name)
	if name and name == normalized then
		if is_argument or type(name) ~= "string" then
			return
		end
		local placeholder = find(name, "\1", nil, true)
		if not placeholder then
			return
		elseif find(name, "\1", placeholder + 1, true) then
			error(format(
				"Internal error: expected %s to only contain one placeholder, but saw %s",
				extra_name and (desc .. dump(extra_name)) or desc, dump(name)
			))
		end
		local first_name = gsub(name, "\1", "1")
		normalized = scribunto_param_key(first_name)
		if first_name == normalized then
			return
		end
		error(format(
			"Internal error: %s cannot resolve to numeric parameters once any placeholder has been substituted, but %s resolves to %s",
			extra_name and (desc .. dump(extra_name)) or desc, dump(name), dump(normalized)
		))
	elseif normalized == nil then
		error(format(
			"Internal error: expected %s to be of type string or number, but saw %s",
			extra_name and (desc .. dump(extra_name)) or desc, type(name)
		))
	end
	error(format(
		"Internal error: expected %s to be Scribunto-compatible: %s (a %s) should be %s (a %s)",
		extra_name and (desc .. dump(extra_name)) or desc, dump(name), type(name), dump(normalized), type(normalized)
	))
end

-- TODO: give ranges instead of long lists, if possible.
local function params_list_error(params, msg)
	local list, n = {}, 0
	for name in sorted_pairs(params) do
		n = n + 1
		list[n] = name
	end
	error(format(
		"Parameter%s %s.",
		format(n == 1 and " %s is" or "s %s are", concat_list(list, " and ", true)),
		msg
	), 3)
end

-- Helper function for use with convert_val_error(). Format a list of possible choices using `concat_list` and
-- conjunction "or", displaying "either " before the choices if there's more than one.
local function format_choice_list(valid)
	return (#valid > 1 and "either " or "") .. concat_list(valid, " or ")
end

-- Signal an error for a value `val` that is not of the right type `valid` (which is either a string specifying a type, or
-- a list of possible values, in the case where `set` was used). `name` is the name of the parameter and can be a
-- function to signal an error (which is assumed to automatically display the parameter's name and value). `seetext` is
-- an optional additional explanatory link to display (e.g. [[WT:LOL]], the list of possible languages and codes).
local function convert_val_error(val, name, valid, seetext)
	if is_callable(name) then
		if type(valid) == "table" then
			valid = "choice, must be " .. format_choice_list(valid)
		end
		name(format("Invalid %s; the value %s is not valid%s", valid, val, seetext and "; see " .. seetext or ""))
	else
		if type(valid) == "table" then
			valid = format_choice_list(valid)
		else
			valid = "a valid " .. valid
		end
		error(format("Parameter %s must be %s; the value %s is not valid.%s", dump(name), valid, dump(val),
			seetext and " See " .. seetext .. "." or ""))
	end
end

-- Generate the appropriate error-signaling function given parameter value `val` and name `name`. If `name` is already
-- a function, it is just returned; otherwise a function is generated and returned that displays the passed-in messaeg
-- along with the parameter's name and value.
local function make_parse_err(val, name)
	if is_callable(name) then
		return name
	end
	return function(msg)
		error(format("%s: parameter %s=%s", msg, name, val))
	end
end

-------------------------------------- Value conversion -----------------------------

-- For a list parameter `name` and corresponding value `list_name` of the `list` field (which should have the same value
-- as `name` if `list = true` was given), generate a pattern to match parameters of the list and store the pattern as a
-- key in `patterns`, with corresponding value set to `name`. For example, if `list_name` is "tr", the pattern will
-- match "tr" as well as "tr1", "tr2", ..., "tr10", "tr11", etc. If the `list_name` contains a \1 in it, the numeric
-- portion goes in place of the \1. For example, if `list_name` is "f\1accel", the pattern will match "faccel",
-- "f1accel", "f2accel", etc. Any \1 in `name` is removed before storing into `patterns`.
local function save_pattern(name, list_name, patterns)
	name = type(name) == "string" and gsub(name, "\1", "") or name
	if find(list_name, "\1", nil, true) then
		patterns["^" .. gsub(pattern_escape(list_name), "\1", "([1-9]%%d*)") .. "$"] = name
	else
		patterns["^" .. pattern_escape(list_name) .. "([1-9]%d*)$"] = name
		list_name = list_name .. "\1"
	end
	validate_name(list_name, "the list field of parameter ", name)
	return patterns
end

-- A helper function for use with `sublist`. It is an iterator function for use in a for-loop that returns split
-- elements of `val` using `sublist` (a Lua split pattern; boolean `true` to split on commas optionally surrounded by
-- whitespace; "comma without whitespace" to split only on commas not followed by whitespace which have not been escaped
-- by a backslash; or a function to do the splitting, which is passed two values, the value to split and a function to
-- signal an error, and should return a list of the split elements). `name` is the parameter name or error-signaling
-- function passed into convert_val().
local function split_sublist(val, name, sublist)
	if sublist == true then
		return gsplit(val, "%s*,%s*")
	elseif sublist == "comma without whitespace" then
		sublist = split_on_comma_without_whitespace
	elseif type(sublist) == "string" then
		return gsplit(val, sublist)
	elseif not is_callable(sublist) then
		error(format('Internal error: expected `sublist` to be of type "string" or "function" or boolean `true`, but saw %s', dump(sublist)))
	end
	return iterate_list(sublist(val, make_parse_err(val, name)))
end

-- For parameter named `name` with value `val` and param spec `param`, if the `set` field is specified, verify that the
-- value is one of the one specified in `set`, and throw an error otherwise. `name` is taken directly from the
-- corresponding parameter passed into convert_val() and may be a function to signal an error. Optional `param_type` is a
-- string specifying the conversion type of `val` and is used for special-casing: If `param_type` is "boolean", an internal
-- error is thrown (since `set` cannot be used in conjunction with booleans) and if `param_type` is "number", no checking
-- happens because in this case `set` contains numbers and is checked inside the number conversion function itself,
-- after converting `val` to a number.
local function check_set(val, name, param, param_type)
	if param_type == "boolean" then
		error(format('Internal error: Cannot use `set` with `type = "%s"`', param_type))
	elseif param_type == "number" then
		-- Needs to be special cased because the check happens after conversion to numbers.
		return
	end
	if not param.set[val] then
		local list = {}
		for k in pairs(param.set) do
			insert(list, dump(k))
		end
		sort(list)
		-- If the parameter is not required then put "or empty" at the end of the list, to avoid implying the parameter is actually required.
		if not param.required then
			insert(list, "empty")
		end
		convert_val_error(val, name, list)
	end
end

local function convert_language(val, name, param, allow_etym)
	local method, func = param.method
	if method == nil or method == "code" then
		func, method = get_language_by_code, "code"
	elseif method == "name" then
		func, method = get_language_by_name, "name"
	else
		error(format('Internal error: expected `method` for type `language` to be "code", "name" or undefined, but saw %s', dump(method)))
	end
	local lang = func(val, nil, allow_etym, param.family)
	if lang then
		return lang
	end
	local list, links = {"language"}, {"[[WT:LOL]]"}
	if allow_etym then
		insert(list, "etymology language")
		insert(links, "[[WT:LOL/E]]")
	end
	if param.family then
		insert(list, "family")
		insert(links, "[[WT:LOF]]")
	end
	convert_val_error(val, name, concat_list(list, " or ") .. " " .. (method == "name" and "name" or "code"), concat_list(links, " and "))
end

-- TODO: validate parameter specs separately, as it's making the handler code really messy at the moment.
local type_handlers = setmetatable({
	["boolean"] = function(val)
		return yesno(val, true)
	end,

	["family"] = function(val, name, param)
		local method, func = param.method
		if method == nil or method == "code" then
			func, method = get_family_by_code, "code"
		elseif method == "name" then
			func, method = get_family_by_name, "name"
		else
			error(format('Internal error: expected `method` for type `family` to be "code", "name" or undefined, but saw %s', dump(method)))
		end
		return func(val) or convert_val_error(val, name, "family " .. method, "[[WT:LOF]]")
	end,

	["labels"] = function(val, name, param)
		-- FIXME: Should be able to pass in a parse_err function.
		return split_labels_on_comma(val)
	end,

	["language"] = function(val, name, param)
		return convert_language(val, name, param, true)
	end,

	["full language"] = function(val, name, param)
		return convert_language(val, name, param)
	end,

	["number"] = function(val, name, param)
		local allow_hex = param.allow_hex
		if allow_hex and allow_hex ~= true then
			error(format('Internal error: expected `allow_hex` for type `number` to be of type "boolean" or undefined, but saw %s', dump(allow_hex)))
		end
		local num = tonumber(val)
		-- Avoid converting inputs like "nan" or "inf", and disallow 0x hex inputs unless explicitly enabled
		-- with `allow_hex`.
		if not (num and is_finite_real_number(num) and (allow_hex or not match(val, "^[+-]?0[Xx]%x*%.?%x*$"))) then
			convert_val_error(val, name, (allow_hex and "decimal or hexadecimal " or "") .. "number")
		-- Track various unusual number inputs to determine if it should be restricted to positive integers by default (possibly including 0).
		elseif not is_positive_integer(num) then
			track("number not a positive integer")
			if num == 0 then
				track("number is 0")
			elseif not is_integer(num) then
				track("number not an integer")
			end
		end
		if param.set then
			-- Don't pass in "number" here; otherwise no checking will happen.
			check_set(num, name, param)
		end
		return num
	end,

	["parameter"] = function(val, name, param)
		-- Use the `no_trim` option, as any trimming will have already been done.
		return scribunto_param_key(val, true)
	end,

	["qualifier"] = function(val, name, param)
		return {val}
	end,

	["references"] = function(val, name, param)
		return parse_references(val, make_parse_err(val, name))
	end,

	["script"] = function(val, name, param)
		local method, func = param.method
		if method == nil or method == "code" then
			func, method = get_script_by_code, "code"
		elseif method == "name" then
			func, method = get_script_by_name, "name"
		else
			error(format('Internal error: expected `method` for type `script` to be "code", "name" or undefined, but saw %s', dump(method)))
		end
		return func(val) or convert_val_error(val, name, "script " .. method, "[[WT:LOS]]")
	end,

	["string"] = function(val, name, param) -- To be removed as unnecessary.
		track("string")
		return val
	end,

	-- TODO: add support for resolving to unsupported titles.
	-- TODO: split this into "page name" (i.e. internal) and "link target" (i.e. external as well), which is more intuitive.
	["title"] = function(val, name, param)
		local namespace = param.namespace
		if namespace == nil then
			namespace = 0
		else
			local valid_type = type(namespace) ~= "number" and 'of type "number" or undefined' or
				not namespaces[namespace] and "a valid namespace number" or
				nil
			if valid_type then
				error(format('Internal error: expected `namespace` for type `title` to be %s, but saw %s', valid_type, dump(namespace)))
			end
		end
		-- Decode entities. WARNING: mw.title.makeTitle must be called with `decoded` (as it doesn't decode) and mw.title.new must be called with `val` (as it does decode, so double-decoding needs to be avoided).
		local decoded, prefix, title = decode_entities(val), param.prefix
		-- If the input is a fragment, treat the title as the current title with the input fragment.
		if sub(decoded, 1, 1) == "#" then
			-- If prefix is "force", only get the current title if it's in the specified namespace. current_title includes the namespace prefix.
			if current_namespace == nil then
				local current_title = mw_title.getCurrentTitle()
				current_title_text, current_namespace = current_title.prefixedText, current_title.namespace
			end
			if not (prefix == "force" and namespace ~= current_namespace) then
				title = new_title(current_title_text .. val)
			end
		elseif prefix == "force" then
			-- Unconditionally add the namespace prefix (mw.title.makeTitle).
			title = make_title(namespace, decoded)
		elseif prefix == "full override" then
			-- The first input prefix will be used as an override (mw.title.new). This can be a namespace or interwiki prefix.
			title = new_title(val, namespace)
		elseif prefix == nil or prefix == "namespace override" then
			-- Only allow namespace prefixes to override. Interwiki prefixes therefore need to be treated as plaintext (e.g. "el:All topics" with namespace 14 returns "el:Category:All topics", but we want "Category:el:All topics" instead; if the former is really needed, then the input ":el:Category:All topics" will work, as the initial colon overrides the namespace). mw.title.new can take namespace names as well as numbers in the second argument, and will throw an error if the input isn't a valid namespace, so this can be used to determine if a prefix is for a namespace, since mw.title.new will return successfully only if there's either no prefix or the prefix is for a valid namespace (in which case we want the override).
			local success
			success, title = pcall(new_title, val, match(decoded, "^.-%f[:]") or namespace)
			-- Otherwise, get the title with mw.title.makeTitle, which unconditionally adds the namespace prefix, but behaves like mw.title.new if the namespace is 0.
			if not success then
				title = make_title(namespace, decoded)
			end
		else
			error(format('Internal error: expected `prefix` for type `title` to be "force", "full override", "namespace override" or undefined, but saw %s', dump(prefix)))
		end
		local allow_external = param.allow_external
		if allow_external == true then
			return title or convert_val_error(val, name, "Wiktionary or external page title")
		elseif not allow_external then
			return title and is_internal_title(title) and title or convert_val_error(val, name, "Wiktionary page title")
		end
		error(format('Internal error: expected `allow_external` for type `title` to be of type "boolean" or undefined, but saw %s', dump(allow_external)))
	end,

	["Wikimedia language"] = function(val, name, param)
		local fallback = param.fallback
		if fallback == true then
			return get_wm_lang_by_code_with_fallback(val) or convert_val_error(val, name, "Wikimedia language or language code")
		elseif not fallback then
			return get_wm_lang_by_code(val) or convert_val_error(val, name, "Wikimedia language code")
		end
		error(format('Internal error: expected `fallback` for type `Wikimedia language` to be of type "boolean" or undefined, but saw %s', dump(fallback)))
	end,
}, {
	-- TODO: decode HTML entities in all input values. Non-trivial to implement, because we need to avoid any downstream functions decoding the output from this module, which would be double-decoding. Note that "title" has this implemented already, and it needs to have both the raw input and the decoded input to avoid double-decoding by me.title.new, so any implementation can't be as simple as decoding in __call then passing the result to the handler.
	__call = function(self, val, name, param, param_type)
		local val_type = type(val)
		-- TODO: check this for all possible parameter types.
		if val_type == param_type then
			return val
		-- TODO: throw an internal error.
		elseif val_type ~= "string" then
			track("input is not string")
			track("input is not string/type handlers")
		end
		local func = self[param_type]
		if func == nil then
			error(format("Internal error: %s is not a recognized parameter type.", dump(param_type)))
		end
		return func(val, name, param)
	end
})

--[==[ func: export.convert_val(val, name, param)
Convert a parameter value according to the associated specs listed in the `params` table passed to
[[Module:parameters]]. `val` is the value to convert for a parameter whose name is `name` (used only in error messages).
`param` is the spec (the value part of the `params` table for the parameter). In place of passing in the parameter name,
`name` can be a function that throws an error, displaying the specified message along with the parameter name and value.
This function processes all the conversion-related fields in `param`, including `type`, `set`, `sublist`, `convert`,
etc. It returns the converted value.
]==]
local function convert_val(val, name, param)
	local param_type = param.type or "string"
	-- If param.type is a function, resolve it to a recognized type.
	if is_callable(param_type) then
		param_type = param_type(val)
	end
	local sublist = param.sublist
	if sublist then
		local retlist = {}
		if type(val) ~= "string" then
			error(format("Internal error: %s is not a string.", dump(val)))
		end
		if param.convert then
			local thisval, insval
			local thisindex = 0
			local parse_err
			if is_callable(name) then
				-- We assume the passed-in error function in `name` already shows the parameter name and raw value.
				function parse_err(msg)
					name(format("%s: item #%s=%s",
						msg_with_processed(msg, thisval, insval), thisindex, thisval)
					)
				end
			else
				function parse_err(msg)
					error(format("%s: item #%s=%s of parameter %s=%s",
						msg_with_processed(msg, thisval, insval), thisindex, thisval, name, val)
					)
				end
			end
			for v in split_sublist(val, name, sublist) do
				thisval = v
				thisindex = thisindex + 1
				if param.set then
					check_set(v, name, param, param_type)
				end
				insert(retlist, param.convert(type_handlers(v, name, param, param_type), parse_err))
			end
		else
			for v in split_sublist(val, name, sublist) do
				if param.set then
					check_set(v, name, param, param_type)
				end
				insert(retlist, type_handlers(v, name, param, param_type))
			end
		end
		return retlist
	else
		if param.set then
			check_set(val, name, param, param_type)
		end
		local retval = type_handlers(val, name, param, param_type)
		if param.convert then
			local parse_err
			if is_callable(name) then
				-- We assume the passed-in error function in `name` already shows the parameter name and raw value.
				if retval == val then
					-- This is an optimization to avoid creating a closure. The second arm works correctly even
					-- when retval == val.
					parse_err = name
				else
					function parse_err(msg)
						name(msg_with_processed(msg, val, retval))
					end
				end
			else
				function parse_err(msg)
					error(format("%s: parameter %s=%s", msg_with_processed(msg, val, retval), name, val))
				end
			end
			retval = param.convert(retval, parse_err)
		end
		return retval
	end
end
export.convert_val = convert_val -- used by [[Module:parameter utilities]]

local function unknown_param(name, val, args_unknown)
	track("unknown parameters")
	args_unknown[name] = val
	return args_unknown
end

local function check_string_param_modifier(param_type, name, tag)
	if param_type and not (param_type == "string" or param_type == "parameter" or type(param_type) == "function") then
		internal_process_error(
			"%s cannot be set unless %s is set to %s (the default), %s or a function: parameter %s has the type %s.",
			tag, "type", "string", "parameter", name, param_type
		)
	end
end

local function hole_error(params, name, listname, this, nxt, extra)
	-- `process_error` calls `dump` on values to be inserted into
	-- error messages, but with numeric lists this causes "numeric"
	-- to look like the name of the list rather than a description,
	-- as `dump` adds quote marks. Insert it early to avoid this,
	-- but add another %s specifier in all other cases, so that
	-- actual list names will be displayed properly.
	local offset, specifier, starting_from = 0, "%s", ""
	local msg = "Item %%d in the list of %s parameters must be given if item %%d is given, because %sthere shouldn't be any gaps due to missing%s parameters."
	local specs = {}
	if type(listname) == "string" then
		specs[2] = listname
	elseif type(name) == "number" then
		offset = name - 1 -- To get the original parameter.
		specifier = "numeric"
		-- If the list doesn't start at parameter 1, avoid implying
		-- there can't be any gaps in the numeric parameters if
		-- some parameter with a lower key is optional.
		for j = name - 1, 1, -1 do
			local _param = params[j]
			if not (_param and _param.required) then
				starting_from = format("(starting from parameter %d) ", dump(j + 1))
				break
			end
		end
	else
		specs[2] = name
	end
	specs[1] = this + offset -- Absolute index for this item.
	insert(specs, nxt + offset) -- Absolute index for the next item.
	process_error(format(msg, specifier, starting_from, extra or ""), unpack(specs))
end

local function check_disallow_holes(params, val, name, listname, extra)
	for i = 1, val.maxindex do
		if val[i] == nil then
			hole_error(params, name, listname, i, num_keys(val)[i], extra)
		end
	end
end

local function handle_holes(params, val, name)
	local param = params[name]
	local disallow_holes = param.disallow_holes
	-- Iterate up the list, and throw an error if a hole is found.
	if disallow_holes then
		check_disallow_holes(params, val, name, param.list, " or empty")
	end
	-- Iterate up the list, and throw an error if a hole is found due to a
	-- missing parameter, treating empty parameters as part of the list. This
	-- applies beyond maxindex if blank arguments are supplied beyond it, so
	-- isn't mutually exclusive with `disallow_holes`.
	local empty = val.empty
	if param.disallow_missing then
		if empty then
			-- Remove `empty` from `val`, so it doesn't get returned.
			val.empty = nil
			for i = 1, max(val.maxindex, maxn(empty)) do
				if val[i] == nil and not empty[i] then
					local keys = extend(num_keys(val), num_keys(empty))
					sort(keys)
					hole_error(params, name, param.list, i, keys[i])
				end
			end
		-- If there's no table of empty parameters, the check is identical to
		-- `disallow_holes`, except that the error message only refers to
		-- missing parameters, not missing or empty ones. If `disallow_holes` is
		-- also set, there's no point checking again.
		elseif not disallow_holes then
			check_disallow_holes(params, val, name, param.list)
		end
	end
	-- If `allow_holes` is set, there's nothing left to do.
	if param.allow_holes then
		return
	-- Otherwise, remove any holes: `pairs` won't work, as it's unsorted, and
	-- iterating from 1 to `maxindex` times out with inputs like |100000000000=,
	-- so use num_keys to get a list of numerical keys sorted from lowest to
	-- highest, then iterate up the list, moving each value in `val` to the
	-- lowest unused positive integer key. This also avoids the need to create a
	-- new table. If `disallow_holes` is specified, then there can't be any
	-- holes in the list, so there's no reason to check again; this doesn't
	-- apply to `disallow_missing`, however.
	elseif not disallow_holes then
		local keys, i = num_keys(val), 0
		while true do
			i = i + 1
			local key = keys[i]
			if key == nil then
				break
			elseif i ~= key then
				val[i], val[key] = val[key], nil
			end
		end
	end
	-- Some code depends on only numeric params being present when no holes are
	-- allowed (e.g. by checking for the presence of arguments using next()), so
	-- remove `maxindex`.
	val.maxindex = nil
end

-- If both `template_default` and `default` are given, `template_default` takes precedence, but only on the template or
-- module page. This means a different default can be specified for the template or module page example. However,
-- `template_default` doesn't apply if any args are set, which helps (somewhat) with examples on documentation pages
-- transcluded into the template page. HACK: We still run into problems on documentation pages transcluded into the
-- template page when pagename= is set. Check this on the assumption that pagename= is fairly standard.
local function convert_default_val(name, param, pagename_set, any_args_set)
	if not pagename_set then
		local val = param.template_default
		if val ~= nil and not any_args_set and is_own_page() then
			return convert_val(val, name, param)
		end
	end
	local val = param.default
	if val ~= nil then
		return convert_val(val, name, param)
	end
end

--[==[
Process arguments with a given list of parameters. Return a table containing the processed arguments. The `args`
parameter specifies the arguments to be processed; they are the arguments you might retrieve from
{frame:getParent().args} (the template arguments) or in some cases {frame.args} (the invocation arguments). The `params`
parameter specifies a list of valid parameters, and consists of a table. If an argument is encountered that is not in
the parameter table, an error is thrown.

The structure of the `params` table is as described above in the intro comment.

'''WARNING:''' The `params` table is destructively modified to save memory. Nonetheless, different keys can share the
same value objects in memory without causing problems.

The `return_unknown` parameter, if set to {true}, prevents the function from triggering an error when it comes across an
argument with a name that it doesn't recognise. Instead, the return value is a pair of values: the first is the
processed arguments as usual, while the second contains all the unrecognised arguments that were left unprocessed. This
allows you to do multi-stage processing, where the entire set of arguments that a template should accept is not known at
once. For example, an inflection-table might do some generic processing on some arguments, but then defer processing of
the remainder to the function that handles a specific inflectional type.
]==]
function export.process(args, params, return_unknown)
	-- Process parameters for specific properties
	local args_new, args_unknown, any_args_set, spec_types, required, patterns, list_args, index_list, args_placeholders, placeholders_n = {}

	-- TODO: memoize the processing of each unique `param` value, since it's common for the same value to be used for many parameter names.
	for name, param in pairs(params) do
		validate_name(name, "parameter names")
		if spec_types == nil then
			spec_types = {}
		end
		local param_spec_type = type(param)
		spec_types[param] = param_spec_type
		if param_spec_type == "table" then
			-- Populate required table, and make sure aliases aren't set to required.
			if param.required then
				if param.alias_of then
					internal_process_error(
						"Parameter %s is an alias of %s, but is also set as a required parameter. Only %s should be set as required.",
						name, param.alias_of, name
					)
				elseif required == nil then
					required = {}
				end
				required[name] = true
			end

			-- FIXME: modifying one of the input tables is a bad idea.
			-- Convert param.set from a list into a set.
			-- `converted_set` prevents double-conversion if multiple parameter keys share the same param table.
			-- rawset avoids errors if param has been loaded via mw.loadData; however, it's probably more efficient to preconvert them, and set the `converted_set` key in advance.
			local set = param.set
			if set and not param.converted_set then
				rawset(param, "set", list_to_set(set))
				rawset(param, "converted_set", true)
			end

			local listname, alias = param.list, param.alias_of
			if alias then
				validate_name(alias, "the alias_of field of parameter ", name)
				-- Check that the alias_of is set to a valid parameter.
				if not params[alias] then
					internal_process_error(
						"Parameter %s is an alias of an invalid parameter.",
						name
					)
				elseif alias == name then
					internal_process_error(
						"Parameter %s cannot be an alias of itself.",
						name
					)
				end
				local main_param = params[alias]
				local main_spec_type = spec_types[main_param] or type(main_param) -- Might not yet be memoized.
				-- Aliases can't be lists unless the canonical parameter is also a list.
				if listname and not (main_spec_type == "table" and main_param.list) then
					internal_process_error(
						"The list parameter %s is set as an alias of %s, which is not a list parameter.", name, alias
					)
				-- Can't be an alias of an alias.
				elseif main_spec_type == "table" then
					local main_alias_of = main_param.alias_of
					if main_alias_of ~= nil then
						internal_process_error(
							"alias_of cannot be set to another alias: parameter %s is set as an alias of %s, which is in turn an alias of %s. Set alias_of for %s to %s.",
							name, alias, main_alias_of, name, main_alias_of
						)
					end
				end
			end

			if listname then
				if not alias then
					local key = name
					if type(name) == "string" then
						key = gsub(name, "\1", "")
					end
					local list_arg = {maxindex = 0}
					args_new[key] = list_arg
					if list_args == nil then
						list_args = {}
					end
					list_args[key] = list_arg
				end
				local list_type = type(listname)
				if list_type == "string" then
					-- If the list property is a string, then it represents the name
					-- to be used as the prefix for list items. This is for use with lists
					-- where the first item is a numbered parameter and the
					-- subsequent ones are named, such as 1, pl2, pl3.
					patterns = save_pattern(name, listname, patterns or {})
				elseif listname ~= true then
					internal_process_error(
						"The list field for parameter %s must be a boolean, string or undefined, but saw a %s.",
						name, list_type
					)
				elseif type(name) == "number" then
					if index_list ~= nil then
						internal_process_error(
							"Only one numeric parameter can be a list, unless the list property is a string."
						)
					end
					-- If the name is a number, then all indexed parameters from
					-- this number onwards go in the list.
					index_list = name
				else
					patterns = save_pattern(name, name, patterns or {})
				end
				if find(name, "\1", nil, true) then
					if args_placeholders then
						placeholders_n = placeholders_n + 1
						args_placeholders[placeholders_n] = name
					else
						args_placeholders, placeholders_n = {name}, 1
					end
				end
			end
		elseif param ~= true then
			internal_process_error(
				"Spec for parameter %s must be a table of specs or the value true, but found %s.",
				name, param_spec_type ~= "boolean" and param_spec_type or param
			)
		end
	end

	--Process required changes to `params`.
	if args_placeholders then
		for i = 1, placeholders_n do
			local name = args_placeholders[i]
			params[gsub(name, "\1", "")], params[name] = params[name], nil
		end
	end

	-- Process the arguments
	for name, val in pairs(args) do
		any_args_set = true
		validate_name(name, "argument names", nil, true)
		-- Once all of these have been eliminated, throw an internal error.
		-- Guaranteeing that all values are strings avoids issues with type coercion being inconsistent between functions.
		if type(val) ~= "string" then
			track("input is not string")
			track("input is not string/raw")
		end
		
		local orig_name, raw_type, index, canonical = name, type(name)

		if raw_type == "number" then
			if index_list and name >= index_list then
				index = name - index_list + 1
				name = index_list
			end
		elseif patterns then
			-- Does this argument name match a pattern?
			for pattern, pname in next, patterns do
				index = match(name, pattern)
				-- It matches, so store the parameter name and the
				-- numeric index extracted from the argument name.
				if index then
					index = tonumber(index)
					name = pname
					break
				end
			end
		end

		local param = params[name]

		-- If the argument is not in the list of parameters, store it in a separate list.
		if not param then
			args_unknown = unknown_param(name, val, args_unknown or {})
		elseif param == true then
			canonical = orig_name
			val = php_trim(val)
			if val ~= "" then
				-- If the parameter is duplicated, throw an error.
				if args_new[name] ~= nil then
					process_error(
						"Parameter %s has been entered more than once. This is probably because a parameter alias has been used.",
						canonical
					)
				end
				args_new[name] = val
			end
		else
			if param.require_index then
				-- Disallow require_index for numeric parameter names, as this doesn't make sense.
				if raw_type == "number" then
					internal_process_error(
						"Cannot set require_index for numeric parameter %s.",
						name
					)
				-- If a parameter without the trailing index was found, and
				-- require_index is set on the param, treat it
				-- as if it isn't recognized.
				elseif not index then
					args_unknown = unknown_param(name, val, args_unknown or {})
				end
			end

			-- Check that separate_no_index is not being used with a numeric parameter.
			if param.separate_no_index then
				if raw_type == "number" then
					internal_process_error(
						"Cannot set separate_no_index for numeric parameter %s.",
						name
					)
				elseif type(param.alias_of) == "number" then
					internal_process_error(
						"Cannot set separate_no_index for parameter %s, as it is an alias of numeric parameter %s.",
						name, param.alias_of
					)
				end
			end

			-- If no index was found, use 1 as the default index.
			-- This makes list parameters like g, g2, g3 put g at index 1.
			-- If `separate_no_index` is set, then use 0 as the default instead.
			if not index and param.list then
				index = param.separate_no_index and 0 or 1
			end

			-- Normalize to the canonical parameter name. If it's a list, but the alias is not, then determine the index.
			local raw_name = param.alias_of
			if raw_name then
				raw_type = type(raw_name)
				if raw_type == "number" then
					name = raw_name
					local main_param = params[raw_name]
					if spec_types[main_param] == "table" and main_param.list then
						if not index then
							index = param.separate_no_index and 0 or 1
						end
						canonical = raw_name + index - 1
					else
						canonical = raw_name
					end
				else
					name = gsub(raw_name, "\1", "")
					local main_param = params[name]
					if not index and spec_types and spec_types[main_param] == "table" and main_param.list then
						index = param.separate_no_index and 0 or 1
					end
					if not index or index == 0 then
						canonical = name
					elseif name == raw_name then
						canonical = name .. index
					else
						canonical = gsub(raw_name, "\1", index)
					end
				end
			else
				canonical = orig_name
			end

			-- Only recognize demo parameters if this is the current template or module's
			-- page, or its documentation page.
			if param.demo and not is_own_page("include_documentation") then
				args_unknown = unknown_param(name, val, args_unknown or {})
			end

			-- Remove leading and trailing whitespace unless no_trim is true.
			if param.no_trim then
				check_string_param_modifier(param.type, name, "no_trim")
			else
				val = php_trim(val)
			end

			-- Empty string is equivalent to nil unless allow_empty is true.
			if param.allow_empty then
				check_string_param_modifier(param.type, name, "allow_empty")
			elseif val == "" then
				-- If `disallow_missing` is set, keep track of empty parameters
				-- via the `empty` field in `arg`, which will be used by the
				-- `disallow_missing` check. This will be deleted before
				-- returning.
				if index and param.disallow_missing then
					local arg = args_new[name]
					local empty = arg.empty
					if empty == nil then
						empty = {}
						arg.empty = empty
					end
					empty[index] = true
				end
				val = nil
			end

			-- Allow boolean false.
			if val ~= nil then
				-- Convert to proper type if necessary.
				local main_param = params[raw_name]
				if not main_param or (spec_types and spec_types[main_param] == "table") then
					val = convert_val(val, orig_name, main_param or param)
				end

				-- Mark it as no longer required, as it is present.
				if required then
					required[name] = nil
				end

				-- Store the argument value.
				if index then
					local arg = args_new[name]
					-- If the parameter is duplicated, throw an error.
					if arg[index] ~= nil then
						process_error(
							"Parameter %s has been entered more than once. This is probably because a list parameter has been entered without an index and with index 1 at the same time, or because a parameter alias has been used.",
							canonical
						)
					end
					arg[index] = val
					-- Store the highest index we find.
					local maxindex = max(index, arg.maxindex)
					if arg[0] ~= nil then
						arg.default, arg[0] = arg[0], nil
						if maxindex == 0 then
							maxindex = 1
						end
					end
					arg.maxindex = maxindex
					if not params[name].list then
						args_new[name] = val
					-- Don't store index 0, as it's a proxy for the default.
					elseif index > 0 then
						arg[index] = val
					end
				else
					-- If the parameter is duplicated, throw an error.
					if args_new[name] ~= nil then
						process_error(
							"Parameter %s has been entered more than once. This is probably because a parameter alias has been used.",
							canonical
						)
					end

					if not raw_name then
						args_new[name] = val
					else
						local main_param = params[raw_name]
						if spec_types[main_param] == "table" and main_param.list then
							local main_arg = args_new[raw_name]
							main_arg[1] = val
							-- Store the highest index we find.
							main_arg.maxindex = max(1, main_arg.maxindex)
						else
							args_new[raw_name] = val
						end
					end
				end
			end
		end
	end

	-- Remove holes in any list parameters if needed. This must be handled
	-- straight after the previous loop, as any instances of `empty` need to be
	-- converted to nil.
	if list_args then
		for name, val in next, list_args do
			handle_holes(params, val, name)
		end
	end

	-- If the current page is the template which invoked this Lua instance, then ignore the `require` flag, as it
	-- means we're viewing the template directly. Required parameters sometimes have a `template_default` key set,
	-- which gets used in such cases as a demo.
	-- Note: this won't work on other pages in the Template: namespace (including the /documentation subpage),
	-- or if the #invoke: is on a page in another namespace.
	local pagename_set = args_new.pagename

	-- Handle defaults.
	for name, param in pairs(params) do
		if spec_types[param] == "table" then
			local arg_new = args_new[name]
			if arg_new == nil then
				args_new[name] = convert_default_val(name, param, pagename_set, any_args_set)
			elseif param.list and arg_new[1] == nil then
				local default_val = convert_default_val(name, param, pagename_set, any_args_set)
				if default_val ~= nil then
					arg_new[1] = default_val
					if arg_new.maxindex == 0 then
						arg_new.maxindex = 1
					end
				end
			end
		end
	end
	
	-- The required table should now be empty.
	-- If any parameters remain, throw an error, unless we're on the current template or module's page.
	if required and next(required) ~= nil and not is_own_page() then
		params_list_error(required, "required")
	-- Return the arguments table.
	-- If there are any unknown parameters, throw an error, unless return_unknown is set, in which case return args_unknown as a second return value.
	elseif return_unknown then
		return args_new, args_unknown or {}
	elseif args_unknown and next(args_unknown) ~= nil then
		params_list_error(args_unknown, "not used by this template")
	end
	return args_new
end

return export
