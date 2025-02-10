local export = {}

local debug_track_module = "Module:debug/track"
local form_of_module = "Module:form of"
local languages_module = "Module:languages"
local load_module = "Module:load"
local parameters_module = "Module:parameters"
local parameter_utilities_module = "Module:parameter utilities"
local parse_interface_module = "Module:parse interface"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local utilities_module = "Module:utilities"

local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local require = require

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

local function format_categories(...)
	format_categories = require(utilities_module).format_categories
	return format_categories(...)
end

local function format_form_of(...)
	format_form_of = require(form_of_module).format_form_of
	return format_form_of(...)
end

local function get_lang(...)
	get_lang = require(languages_module).getByCode
	return get_lang(...)
end

local function gsplit(...)
	gsplit = require(string_utilities_module).gsplit
	return gsplit(...)
end

local function load_data(...)
	load_data = require(load_module).load_data
	return load_data(...)
end

local function parse_inline_modifiers(...)
	parse_inline_modifiers = require(parse_interface_module).parse_inline_modifiers
	return parse_inline_modifiers(...)
end

local function pattern_escape(...)
	pattern_escape = require(string_utilities_module).pattern_escape
	return pattern_escape(...)
end

local function process_params(...)
	process_params = require(parameters_module).process
	return process_params(...)
end

local function safe_load_data(...)
	safe_load_data = require(load_module).safe_load_data
	return safe_load_data(...)
end

local function split(...)
	split = require(string_utilities_module).split
	return split(...)
end

local function split_tag_set(...)
	split_tag_set = require(form_of_module).split_tag_set
	return split_tag_set(...)
end

local function tagged_inflections(...)
	tagged_inflections = require(form_of_module).tagged_inflections
	return tagged_inflections(...)
end

local function trim(...)
	trim = require(string_utilities_module).trim
	return trim(...)
end

local function ucfirst(...)
	ucfirst = require(string_utilities_module).ucfirst
	return ucfirst(...)
end

--[==[
Loaders for objects, which load data (or some other object) into some variable, which can then be accessed as "foo or get_foo()", where the function get_foo sets the object to "foo" and then returns it. This ensures they are only loaded when needed, and avoids the need to check for the existence of the object each time, since once "foo" has been set, "get_foo" will not be called again.]==]
local force_cat
local function get_force_cat()
	force_cat, get_force_cat = require(form_of_module).force_cat, nil
	return force_cat
end

local m_form_of_pos
local function get_m_form_of_pos()
	m_form_of_pos, get_m_form_of_pos = load_data(require(form_of_module).form_of_pos_module), nil
	return m_form_of_pos
end

local module_prefix
local function get_module_prefix()
	module_prefix, get_module_prefix = require(form_of_module).form_of_lang_data_module_prefix, nil
	return module_prefix
end

--[==[ intro:
This module contains code that directly implements {{tl|form of}}, {{tl|inflection of}}, and the various other
[[:Category:Form-of templates|form-of templates]]. It is meant to be called directly from templates. See also
[[Module:form of]], which contains the underlying implementing code and is meant to be called from other modules.
]==]

-- Add tracking category for PAGE when called from TEMPLATE. The tracking category linked to is
-- [[Wiktionary:Tracking/form-of/TEMPLATE/PAGE]]. If TEMPLATE is omitted, the tracking category is of the form
-- [[Wiktionary:Tracking/form-of/PAGE]].
local function track(page, template)
	debug_track("form-of/" .. (template and template .. "/" or "") .. page)
end


local function get_common_template_params()
	return {
		-- Named params not controlling link display
		["cat"] = {list = true},
		["notext"] = {type = "boolean"},
		["sort"] = true,
		["enclitic"] = true,
		-- FIXME! The following should only be available when withcap=1 in invocation args or when withencap=1 and the
		-- language is "en". Before doing that, need to remove all uses of nocap= in other circumstances.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when withdot=1 in invocation args. Before doing that, need to
		-- remove all uses of nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		["addl"] = true, -- additional text to display at the end, before the closing </span>
		["pagename"] = true, -- for testing, etc.
	}
end

-- Split TAGSPECS (inflection tag specifications) on SPLIT_REGEX, which
-- may be nil for no splitting.
local function split_inflection_tags(tagspecs, split_regex)
	if not split_regex then
		return tagspecs
	end
	local inflection_tags = {}
	for _, tagspec in ipairs(tagspecs) do
		for tag in gsplit(tagspec, split_regex) do
			insert(inflection_tags, tag)
		end
	end
	return inflection_tags
end


local function parse_terms_with_inline_modifiers(paramname, val, param_mods, lang)
	local function generate_obj(term)
		return {lang = lang, term = decode_entities(term)}
	end

	return parse_inline_modifiers(val, {
		paramname = paramname,
		param_mods = param_mods,
		generate_obj = generate_obj,
		splitchar = ",",
	})
end


-- Modify PARAMS in-place by adding parameters that control the link to the
-- main entry. TERM_PARAM is the number of the param specifying the main
-- entry itself; TERM_PARAM + 1 will be the display text, and TERM_PARAM + 2
-- will be the gloss, unless NO_NUMBERED_GLOSS is given.
local function add_link_params(parent_args, params, term_param, no_numbered_gloss)
	params[term_param + 1] = {alias_of = "alt"}
	if not no_numbered_gloss then
		params[term_param + 2] = {alias_of = "t"}
	end
	-- Numbered params controlling link display
	params[term_param] = true
end

-- Need to do what [[Module:parameters]] does to string arguments from parent_args as we're running this
-- before calling [[Module:parameters]] on parent_args.
local function ine(arg)
	if not arg then
		return nil
	end
	arg = trim(arg)
	return arg ~= "" and arg or nil
end

local function add_base_lemma_params(parent_args, iargs, params, compat)
	-- Check the language-specific data for additional base lemma params. But if there's no language-specific data,
	-- attempt any parent varieties as well (i.e. superordinate varieties).
	local lang = get_lang(ine(parent_args[compat and "lang" or 1]) or ine(iargs.lang) or "und", nil, true)
	while lang do
		local langdata = safe_load_data((module_prefix or get_module_prefix()) .. lang:getCode())
		if langdata then
			local base_lemma_params = langdata.base_lemma_params
			if base_lemma_params then
				for _, param in ipairs(base_lemma_params) do
					params[param.param] = true
				end
				return base_lemma_params
			end
		end
		lang = lang:getParent()
	end
end

local function add_link_and_base_lemma_params(iargs, parent_args, params, term_param, compat, no_numbered_gloss)
	local base_lemma_params
	if not iargs.nolink and not iargs.linktext then
		add_link_params(parent_args, params, term_param, no_numbered_gloss)
		base_lemma_params = add_base_lemma_params(parent_args, iargs, params, compat)
	end
	return base_lemma_params
end

local function handle_withdot_withcap(iargs, params)
	local ignored_tracked_params = {}

	if iargs.withdot then
		params.dot = true
	else
		ignored_tracked_params.nodot = true
	end

	if iargs.withcap and iargs.withencap then
		error("Internal error: Can specify only one of withcap= and withencap=")
	end

	if not iargs.withcap then
		params.cap = {type = "boolean"}
		ignored_tracked_params.nocap = true
	end

	return ignored_tracked_params
end


--[=[
Construct and return the full definition line for a form-of-type template invocation. `data` is an object with the
following fields:
* `template`: Approximate template name, for debug tracking;
* `iargs`: processed invocation arguments;
* `parent_args`: raw parent args from `frame:getParent().args`;
* `params`: partially constructed params structure of the sort passed to `process()` in [[Module:parameters]], but
  without any link params;
* `ignored_tracked_params`: params that are ignored but should be tracked, to be eventually removed;
* `term_param`: the parent argument specifying the main entry;
* `compat`: true if the language code is found in args.lang instead of args[1];
* `base_lemma_params`: if non-nil, a list of base lemma param objects of the sort stored in the language-specific data;
* `do_form_of`: a function of one argument, `lemma_data`, that returns the actual definition-line text and any
  language-specific categories. See below.

This function does several things:
# If link parameters are called for (neither `iargs.nolink` nor `iargs.linktext` are given), augment the `params`
  structure with separate link parameters.
# Modify the parent args as appropriate if invocation arguments def= or ignore= are given.
# Parse the parent args, both for separate parameter properties and inline modifiers on the term parameter (which may
  consist of multiple comma-separated terms).
# Compute categories to add to the page, including language-specific categories and any categories requested by the
  invocation or parent args.
# Parse enclitic and extra base lemma parameters.
# Construct the actual text using `do_form_of`.
# Add a terminating period/dot as appropriate, along with the formatted categories.

`do_form_of` takes one argument, `lemma_data`, which looks like this:
{
	lang = LANG,
	args = {ARG = VALUE, ARG = VALUE, ...},
	lemmas = {LEMMA_OBJ, LEMMA_OBJ, ...},
	enclitics = {ENCLITIC_OBJ, ENCLITIC_OBJ, ...},
	base_lemmas = {BASE_LEMMA_OBJ, BASE_LEMMA_OBJ, ...},
	categories = {"CATEGORY", "CATEGORY", ...},
	posttext = "POSTTEXT" or nil,
}

where

* LANG is the language code;
* ARGS is the parsed arguments, based on what the user specified;
* LEMMAS is a sequence of objects specifying the main entries/lemmas, as passed to full_link in [[Module:links]];
  however, if the invocation argument linktext= is given, it will be a string consisting of that text, and if the
  invocation argument nolink= is given, it will be nil;
* ENCLITICS is nil or a sequence of objects specifying the enclitics, as passed to full_link in [[Module:links]];
* BASE_LEMMA_OBJ is a sequence of objects specifying the base lemma(s), which are used when the lemma is itself a
  form of another lemma (the base lemma), e.g. a comparative, superlative or participle; each object is of the form
  { paramobj = PARAM_OBJ, lemmas = {LEMMA_OBJ, LEMMA_OBJ, ...} } where PARAM_OBJ describes the properties of the
  base lemma parameter (i.e. the relationship between the intermediate and base lemmas) and LEMMA_OBJ is of the same
  format of ENCLITIC_OBJ, i.e. an object suitable to be passed to full_link in [[Module:links]]; PARAM_OBJ is of the
  format { param = "PARAM", tags = {"TAG", "TAG", ...} } where PARAM is the name of the parameter to
  {{inflection of}} etc. that holds the base lemma(s) of the specified relationship and the tags describe the
  relationship, such as {"comd"} or {"past", "part"};
* CATEGORIES is the categories to add the page to (consisting of any categories specified in the invocation or
  parent args and any tracking categories, but not any additional lang-specific categories that may be added by
  {{inflection of}} or similar templates);
* POSTTEXT is text to display at the end of the form-of text, before the final </span> (or at the end of the first
  line, before the colon, in a multiline {{infl of}} call).

`do_form_of` should return two arguments:

(1) The actual definition-line text, marked up appropriately with <span>...</span> but without any terminating
    period/dot.
(2) Any extra categories to add the page to (other than those that can be derived from parameters specified to the
    invocation or parent arguments, which will automatically be added to the page).
]=]
local function construct_form_of_text(data)
	local template, iargs, parent_args, params, no_numbered_gloss, do_form_of =
		data.template, data.iargs, data.parent_args, data.params, data.no_numbered_gloss, data.do_form_of

	local term_param = iargs.term_param
	local compat = iargs.lang or parent_args.lang
	term_param = term_param or compat and 1 or 2

	-- Numbered params
	params[compat and "lang" or 1] = {
		required = not iargs.lang,
		type = "language",
		default = iargs.lang or "und"
	}

	local base_lemma_params = add_link_and_base_lemma_params(iargs, parent_args, params, term_param, compat,
		no_numbered_gloss)
	local ignored_tracked_params = handle_withdot_withcap(iargs, params)

	--[=[
	Process parent arguments. This is similar to the following:
		require("Module:parameters").process(parent_args, params)
	but in addition it does the following:
	(1) Supplies default values for unspecified parent arguments as specified in
		DEFAULTS, which consist of specs of the form "ARG=VALUE". These are
		added to the parent arguments prior to processing, so boolean and number
		parameters will process the value appropriately.
	(2) Removes parent arguments specified in IGNORESPECS, which consist either
		of bare argument names to remove, or list-argument names to remove of the
		form "ARG:list".
	(3) Tracks the use of any parent arguments specified in TRACKED_PARAMS, which
		is a set-type table where the keys are arguments as they exist after
		processing (hence numeric arguments should be numbers, not strings)
		and the values should be boolean true.
	]=]--
	local defaults = iargs.def
	local ignorespecs = iargs.ignore
	if defaults[1] or ignorespecs[1] then
		local new_parent_args = {}
		for _, default in ipairs(defaults) do
			local defparam, defval = default:match("^(.-)=(.*)$")
			if not defparam then
				error("Bad default spec " .. default)
			end
			new_parent_args[defparam] = defval
		end

		local params_to_ignore = {}
		local numbered_list_params_to_ignore = {}
		local named_list_params_to_ignore = {}

		for _, ignorespec in ipairs(ignorespecs) do
			for ignore in gsplit(ignorespec, ",") do
				local param = ignore:match("^(.*):list$")
				if param then
					if param:match("^%d+$") then
						insert(numbered_list_params_to_ignore, tonumber(param))
					else
						insert(named_list_params_to_ignore, "^" .. pattern_escape(param) .. "%d*$")
					end
				else
					if ignore:match("^%d+$") then
						ignore = tonumber(ignore)
					end
					params_to_ignore[ignore] = true
				end
			end
		end

		for k, v in pairs(parent_args) do
			if not params_to_ignore[k] then
				local ignore_me = false
				if type(k) == "number" then
					for _, lparam in ipairs(numbered_list_params_to_ignore) do
						if k >= lparam then
							ignore_me = true
							break
						end
					end
				else
					for _, lparam in ipairs(named_list_params_to_ignore) do
						if k:match(lparam) then
							ignore_me = true
							break
						end
					end
				end
				if not ignore_me then
					new_parent_args[k] = v
				end
			end
		end
		parent_args = new_parent_args
	end

	local m_param_utils, param_mods

	local function init_param_mods()
		if not m_param_utils then
			m_param_utils = require(parameter_utilities_module)
			param_mods = m_param_utils.construct_param_mods {
				{group = {"link", "q", "l", "ref"}},
			}
		end
	end

	local terms, args
	if iargs.nolink or iargs.linktext then
		args = process_params(parent_args, params)
	else
		init_param_mods()
		terms, args = m_param_utils.parse_term_with_inline_modifiers_and_separate_params {
			params = params,
			param_mods = param_mods,
			raw_args = parent_args,
			termarg = term_param,
			track_module = "form-of" .. (template and "/" .. template or ""),
			lang = compat and "lang" or 1,
			sc = "sc",
			-- Don't do this, doesn't seem to make sense.
			-- parse_lang_prefix = true,
			make_separate_g_into_list = true,
			process_args_before_parsing = function(args)
				-- For compatibility with the previous code, we accept a comma-separated list of genders in each of g=,
				-- g2=, etc. in addition to separate genders in g=/g2=/etc.
				if args.g and args.g[1] then
					local genders = {}
					for _, g in ipairs(args.g) do
						extend(genders, split(g, ","))
					end
					args.g = genders
				end
			end,
			splitchar = ",",
			subitem_param_handling = "last",
		}
	end

	-- Tracking for certain user-specified params. This is generally used for
	-- parameters that we accept but ignore, so that we can eventually remove
	-- all uses of these params and stop accepting them.
	if ignored_tracked_params then
		for ignored_tracked_param, _ in pairs(ignored_tracked_params) do
			if parent_args[ignored_tracked_param] then
				track("arg/" .. ignored_tracked_param, template)
			end
		end
	end

	local lang = args[compat and "lang" or 1]

	-- Determine categories for the page, including tracking categories

	local categories = {}

	if not args.nocat then
		for _, cat in ipairs(iargs.cat) do
			insert(categories, lang:getFullName() .. " " .. cat)
		end
	end
	for _, cat in ipairs(args.cat) do
		insert(categories, lang:getFullName() .. " " .. cat)
	end

	-- Format the link, preceding text and categories

	local function add_term_tracking_categories(term)
		-- add tracking category if term is same as page title
		if term and mw.title.getCurrentTitle().text == (lang:makeEntryName(term)) then
			insert(categories, "Forms linking to themselves")
		end
		-- maybe add tracking category if primary entry doesn't exist (this is an
		-- expensive call so we don't do it by default)
		if iargs.noprimaryentrycat and term and mw.title.getCurrentTitle().nsText == ""
			and not mw.title.new(term):getContent() then
			insert(categories, lang:getFullName() .. " " .. iargs.noprimaryentrycat)
		end
	end

	local lemmas

	if iargs.nolink then
		lemmas = nil
	elseif iargs.linktext then
		lemmas = iargs.linktext
	else
		if not terms.terms[1] then
			if mw.title.getCurrentTitle().nsText == "Template" then
				terms.terms[1] = {
					lang = lang,
					term = "term"
				}
			else
				error("No linked-to term specified")
			end
		end
		for _, termobj in ipairs(terms.terms) do
			if termobj.term then
				add_term_tracking_categories(termobj.term)
			end

			-- NOTE: Formerly, template arg sc= overrode inline modifier <sc:...>, which seems backwards, so I've
			-- changed it. Hopefully nothing depended on the old behavior.
		end

		lemmas = terms.terms
	end

	local enclitics
	if args.enclitic then
		init_param_mods()
		enclitics = parse_terms_with_inline_modifiers("enclitic", args.enclitic, param_mods, lang)
	end
	local base_lemmas = {}
	if base_lemma_params then
		for _, base_lemma_param_obj in ipairs(base_lemma_params) do
			local param = base_lemma_param_obj.param
			if args[param] then
				init_param_mods()
				insert(base_lemmas, {
					paramobj = base_lemma_param_obj,
					lemmas = parse_terms_with_inline_modifiers(param, args[param], param_mods, lang),
				})
			end
		end
	end

	local posttext = iargs.posttext
	local addl = args.addl
	if addl then
		posttext = posttext or ""
		if addl:find("^[;:]") then
			posttext = posttext .. addl
		elseif addl:find("^_") then
			posttext = posttext .. " " .. addl:sub(2)
		else
			posttext = posttext .. ", " .. addl
		end
	end

	local lemma_data = {
		lang = lang,
		args = args,
		lemmas = lemmas,
		enclitics = enclitics,
		base_lemmas = base_lemmas,
		categories = categories,
		posttext = posttext,
	}

	local form_of_text, lang_cats = do_form_of(lemma_data)
	extend(lemma_data.categories, lang_cats)
	local text = form_of_text .. (
		args.nodot and "" or args.dot or iargs.withdot and "." or ""
	)
	if #lemma_data.categories == 0 then
		return text
	end
	return text .. format_categories(lemma_data.categories, lemma_data.lang, args.sort,
		-- If lemma_is_sort_key is given, supply the first lemma term as the sort base if possible. If sort= is given,
		-- it will override the base; otherwise, the base will be converted appropriately to a sort key using the
		-- same algorithm applied to pagenames.
		iargs.lemma_is_sort_key and type(lemma_data.lemmas) == "table" and lemma_data.lemmas[1].term,
		-- Supply the first lemma's script for sort key computation.
		force_cat or get_force_cat(), type(lemma_data.lemmas) == "table" and lemma_data.lemmas[1].sc)
end


-- Invocation parameters shared between form_of_t(), tagged_form_of_t() and inflection_of_t().
local function get_common_invocation_params()
	return {
		["term_param"] = {type = "number"},
		["lang"] = true, -- To be used as the default code in params.
		["sc"] = {type = "script"},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["def"] = {list = true},
		["withcap"] = {type = "boolean"},
		["withencap"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["nolink"] = {type = "boolean"},
		["linktext"] = true,
		["posttext"] = true,
		["noprimaryentrycat"] = true,
		["lemma_is_sort_key"] = true,
	}
end


local function should_ucfirst_text(args, iargs, lang)
	return args.cap or (iargs.withcap or iargs.withencap and lang:getCode() == "en") and not args.nocap
end


--[==[
Function that implements {{tl|form of}} and the various more specific form-of templates (but not {{tl|inflection of}}
or templates that take tagged inflection parameters).

Invocation params:

; {{para|1|req=1}}
: Text to display before the link.
; {{para|term_param}}
: Numbered param holding the term linked to. Other numbered params come after. Defaults to 1 if invocation or template
  param {{para|lang}} is present, otherwise 2.
; {{para|lang}}
: Default language code for language-specific templates. If specified, no language code needs to be specified, and if
  specified it needs to be set using {{para|lang}}, not {{para|1}}.
; {{para|sc}}
: Default script code for language-specific templates. The script code can still be overridden using template param
  {{para|sc}}.
; {{para|cat}}, {{para|cat2}}, ...:
: Categories to place the page into. The language name will automatically be prepended. Note that there is also a
  template param {{para|cat}} to specify categories at the template level. Use of {{para|nocat}} disables categorization
  of categories specified using invocation param {{para|cat}}, but not using template param {{para|cat}}.
; {{para|ignore}}, {{para|ignore2}}, ...:
: One or more template params to silently accept and ignore. Useful e.g. when the template takes additional parameters
  such as {{para|from}} or {{para|POS}}. Each value is a comma-separated list of either bare parameter names or
  specifications of the form `PARAM:list` to specify that the parameter is a list parameter.
; {{para|def}}, {{para|def2}}, ...:
: One or more default values to supply for template args. For example, specifying {{para|def|2=tr=-}} causes the default
  for template param {{para|tr}} to be `-`. Actual template params override these defaults.
; {{para|withcap}}
: Capitalize the first character of the text preceding the link, unless template param {{para|nocap}} is given.
; {{para|withencap}}
: Capitalize the first character of the text preceding the link if the language is English and template param
  {{para|nocap}} is not given.
; {{para|withdot}}
: Add a final period after the link, unless template param {{para|nodot}} is given to suppress the period, or
  {{para|dot}} is given to specify an alternative punctuation character.
; {{para|nolink}}
: Suppress the display of the link. If specified, none of the template params that control the link
  ({{para|<var>term_param</var>}}, {{para|<var>term_param</var> + 1}}, {{para|<var>term_param</var> + 2}}, {{para|t}},
  {{para|gloss}}, {{para|sc}}, {{para|tr}}, {{para|ts}}, {{para|pos}}, {{para|g}}, {{para|id}}, {{para|lit}}) will be
  available. If the calling template uses any of these parameters, they must be ignored using {{para|ignore}}.
 {{para|linktext}}
: Override the display of the link with the specified text. This is useful if a custom template is available to format
  the link (e.g. in Hebrew, Chinese and Japanese). If specified, none of the template params that control the link
  ({{para|<var>term_param</var>}}, {{para|<var>term_param</var> + 1}}, {{para|<var>term_param</var> + 2}}, {{para|t}},
  {{para|gloss}}, {{para|sc}}, {{para|tr}}, {{para|ts}}, {{para|pos}}, {{para|g}}, {{para|id}}, {{para|lit}}) will be
  available. If the calling template uses any of these parameters, they must be ignored using {{para|ignore}}.
; {{para|posttext}}
: Additional text to display directly after the formatted link, before any terminating period/dot and inside of
  `<span class='use-with-mention'>`.
; {{para|noprimaryentrycat}}
: Category to add the page to if the primary entry linked to doesn't exist. The language name will automatically be
  prepended.
; {{para|lemma_is_sort_key}}
: If the user didn't specify a sort key, use the lemma as the sort key (instead of the page itself).
]==]
function export.form_of_t(frame)
	local iparams = get_common_invocation_params()
	iparams[1] = {required = true}
	local iargs = process_params(frame.args, iparams)
	local parent_args = frame:getParent().args

	local params = get_common_template_params()

	if next(iargs.cat) then
		params.nocat = {type = "boolean"}
	end

	return construct_form_of_text {
		template = "form-of-t",
		iargs = iargs,
		parent_args = parent_args,
		params = params,
		do_form_of = function(lemma_data)
			local args = lemma_data.args
			local text
			if args.notext then
				text = ""
			else
				text = iargs[1]
				if should_ucfirst_text(args, iargs, lemma_data.lang) then
					text = ucfirst(text)
				end
			end
			return format_form_of {
				text = text, lemmas = lemma_data.lemmas, enclitics = lemma_data.enclitics,
				base_lemmas = lemma_data.base_lemmas, lemma_face = "term", posttext = lemma_data.posttext
			}, {}
		end
	}
end


--[=[
Construct and return the full definition line for a form-of-type template invocation that is based on inflection tags.
This is a wrapper around construct_form_of_text() and takes the following arguments: processed invocation arguments
IARGS, processed parent arguments ARGS, TERM_PARAM (the parent argument specifying the main entry), COMPAT (true if the
language code is found in args.lang instead of args[1]), and TAGS, the list of (non-canonicalized) inflection tags.
It returns that actual definition-line text including terminating period/full-stop, formatted categories, etc. and
should be directly returned as the template function's return value.
]=]
local function construct_tagged_form_of_text(data)
	local template, iargs, parent_args, params, no_numbered_gloss, tags =
		data.template, data.iargs, data.parent_args, data.params, data.no_numbered_gloss, data.tags

	-- Named params not controlling link display
	-- Always included because lang-specific categories may be added
	params.nocat = {type = "boolean"}
	params.p = true
	params.POS = {alias_of = "p"}

	return construct_form_of_text {
		template = template,
		iargs = iargs,
		parent_args = parent_args,
		params = params,
		no_numbered_gloss = no_numbered_gloss,
		do_form_of = function(lemma_data)
			local args = lemma_data.args
			if type(tags) == "function" then
				tags = tags(args)
			end
			-- NOTE: tagged_inflections returns two values, so we do too.
			return tagged_inflections {
				lang = lemma_data.lang,
				tags = tags,
				lemmas = lemma_data.lemmas,
				enclitics = lemma_data.enclitics,
				base_lemmas = lemma_data.base_lemmas,
				lemma_face = "term",
				POS = args.p,
				pagename = args.pagename,
				-- Set no_format_categories because we do it ourselves in construct_form_of_text().
				no_format_categories = true,
				nocat = args.nocat,
				notext = args.notext,
				capfirst = should_ucfirst_text(args, iargs, lemma_data.lang),
				posttext = lemma_data.posttext,
			}
		end
	}
end


--[==[
Function that implements form-of templates that are defined by specific tagged inflections (typically a template
referring to a non-lemma inflection, such as {{tl|plural of}}). This works exactly like {form_of_t()} except that the
"form of" text displayed before the link is based off of a pre-specified set of inflection tags (which will be
appropriately linked to the glossary) instead of arbitrary text. From the user's perspective, there is no difference
between templates implemented using {form_of_t()} and {tagged_form_of_t()}; they accept exactly the same parameters and
work the same. See also {inflection_of_t()} below, which is intended for templates with user-specified inflection tags.

Invocation params:

; {{para|1|req=1}}, {{para|2}}, ...
: One or more inflection tags describing the inflection in question.
; {{para|split_tags}}
: If specified, character to split specified inflection tags on. This allows multiple tags to be included in a single
  argument, simplifying template code.
; {{para|term_param}}
; {{para|lang}}
; {{para|sc}}
; {{para|cat}}, {{para|cat2}}, ...
; {{para|ignore}}, {{para|ignore2}}, ...
; {{para|def}}, {{para|def2}}, ...
; {{para|withcap}}
; {{para|withencap}}
; {{para|withdot}}
; {{para|nolink}}
; {{para|linktext}}
; {{para|posttext}}
; {{para|noprimaryentrycat}}
; {{para|lemma_is_sort_key}}
: All of these are the same as in {form_of_t()}.
]==]
function export.tagged_form_of_t(frame)
	local iparams = get_common_invocation_params()
	iparams[1] = {list = true, required = true}
	iparams.split_tags = true

	local iargs = process_params(frame.args, iparams)
	local parent_args = frame:getParent().args
	local params = get_common_template_params()

	return construct_tagged_form_of_text {
		template = "tagged-form-of-t",
		iargs = iargs,
		parent_args = parent_args,
		params = params,
		tags = split_inflection_tags(iargs[1], iargs.split_tags),
	}
end

--[==[
Function that implements {{tl|inflection of}} and certain semi-specific variants, such as {{tl|participle of}} and
{{tl|past participle form of}}. This function is intended for templates that allow the user to specify a set of
inflection tags.

It works similarly to {form_of_t()} and {tagged_form_of_t()} except that the calling convention for the calling
template is
: { {{TEMPLATE|LANG|MAIN_ENTRY_LINK|MAIN_ENTRY_DISPLAY_TEXT|TAG|TAG|...}}}

instead of
: { {{TEMPLATE|LANG|MAIN_ENTRY_LINK|MAIN_ENTRY_DISPLAY_TEXT|GLOSS}}}

Note that there isn't a numbered parameter for the gloss, but it can still be specified using {{para|t}} or
{{para|gloss}}.

Invocation params:

; {{para|preinfl}}, {{para|preinfl2}}, ...
: Extra inflection tags to automatically prepend to the tags specified by the template.
; {{para|postinfl}}, {{para|postinfl2}}, ...
: Extra inflection tags to automatically append to the tags specified by the template. Used for example by
  {{tl|past participle form of}} to add the tags `of the|past|p` onto the user-specified tags, which indicate which
  past participle form the page refers to.
; {{para|split_tags}}
: If specified, character to split specified inflection tags on. This allows multiple tags to be included in a single
  argument, simplifying template code. Note that this applies *ONLY* to inflection tags specified in the invocation
  arguments using {{para|preinfl}} or {{para|postinfl}}, not to user-specified inflection tags.
; {{para|term_param}}
; {{para|lang}}
; {{para|sc}}
; {{para|cat}}, {{para|cat2}}, ...
; {{para|ignore}}, {{para|ignore2}}, ...
; {{para|def}}, {{para|def2}}, ...
; {{para|withcap}}
; {{para|withencap}}
; {{para|withdot}}
; {{para|nolink}}
; {{para|linktext}}
; {{para|posttext}}
; {{para|noprimaryentrycat}}
; {{para|lemma_is_sort_key}}
: All of these are the same as in {form_of_t()}.
]==]
function export.inflection_of_t(frame)
	local iparams = get_common_invocation_params()
	iparams.preinfl = {list = true}
	iparams.postinfl = {list = true}
	iparams.split_tags = true

	local iargs = process_params(frame.args, iparams)
	local parent_args = frame:getParent().args
	local params = get_common_template_params()

	local compat = iargs.lang or parent_args.lang
	local tagsind = (iargs.term_param or compat and 1 or 2) + 2

	params[tagsind] = {list = true,
		-- at least one inflection tag is required unless preinfl or postinfl tags are given
		required = #iargs.preinfl == 0 and #iargs.postinfl == 0}

	return construct_tagged_form_of_text {
		template = "inflection-of-t",
		iargs = iargs,
		parent_args = parent_args,
		params = params,
		no_numbered_gloss = true,
		tags = function(args)
			local infls
			if not next(iargs.preinfl) and not next(iargs.postinfl) then
				-- If no preinfl or postinfl tags, just use the user-specified tags directly.
				infls = args[tagsind]
			else
				-- Otherwise, we need to prepend the preinfl tags and postpend the postinfl tags. If there's only one tag set
				-- (no semicolon), it's easier. Since this is common, we optimize for it.
				infls = {}
				local saw_semicolon = false
				for _, infl in ipairs(args[tagsind]) do
					if infl == ";" then
						saw_semicolon = true
						break
					end
				end
				local split_preinfl = split_inflection_tags(iargs.preinfl, iargs.split_tags)
				local split_postinfl = split_inflection_tags(iargs.postinfl, iargs.split_tags)
				if not saw_semicolon then
					extend(infls, split_preinfl)
					extend(infls, args[tagsind])
					extend(infls, split_postinfl)
				else
					local groups = split_tag_set(args[tagsind])
					for _, group in ipairs(groups) do
						if #infls > 0 then
							insert(infls, ";")
						end
						extend(infls, split_preinfl)
						extend(infls, group)
						extend(infls, split_postinfl)
					end
				end
			end
			return infls
		end,
	}
end

--[==[
Normalize a part-of-speech tag given a possible abbreviation (passed in as {{para|1}} of the invocation args). If the
abbreviation isn't recognized, the original POS tag is returned. If no POS tag is passed in, return the value of
invocation arg {{para|default}}.
]==]
function export.normalize_pos(frame)
	local iparams = {
		[1] = true,
		["default"] = true,
	}
	local iargs = process_params(frame.args, iparams)
	if not iargs[1] and not iargs.default then
		error("Either 1= or default= must be given in the invocation args")
	end
	if not iargs[1] then
		return iargs.default
	end
	return (m_form_of_pos or get_m_form_of_pos())[iargs[1]] or iargs[1]
end

return export
