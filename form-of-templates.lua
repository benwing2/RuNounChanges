local export = {}

local force_cat = false -- for testing; set to true to display categories even on non-mainspace pages

local m_form_of = require("Module:form of")
local m_form_of_pos = require("Module:form of/pos")
local m_params = require("Module:parameters")
local put_module = "Module:parse utilities"
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rgsplit = mw.text.gsplit

-- Add tracking category for PAGE when called from TEMPLATE. The tracking category linked to is
-- [[Template:tracking/form-of/TEMPLATE/PAGE]]. If TEMPLATE is omitted, the tracking category is of the form
-- [[Template:tracking/form-of/PAGE]].
local function track(page, template)
	require("Module:debug/track")("form-of/" .. (template and template .. "/" or "") .. page)
end


-- Equivalent to list.extend(new_items) in Python. Appends items in `new_items` (a list) to `list`.
local function extend_list(list, new_items)
	for _, item in ipairs(new_items) do
		table.insert(list, item)
	end
end


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
local function process_parent_args(template, parent_args, params, defaults, ignorespecs, tracked_params, function_name)
	if #defaults > 0 or #ignorespecs > 0 then
		local new_parent_args = {}
		for _, default in ipairs(defaults) do
			local defparam, defval = rmatch(default, "^(.-)=(.*)$")
			if not defparam then
				error("Bad default spec " .. default)
			end
			new_parent_args[defparam] = defval
		end

		local params_to_ignore = {}
		local numbered_list_params_to_ignore = {}
		local named_list_params_to_ignore = {}

		for _, ignorespec in ipairs(ignorespecs) do
			for ignore in rgsplit(ignorespec, ",") do
				local param = rmatch(ignore, "^(.*):list$")
				if param then
					if rfind(param, "^[0-9]+$") then
						table.insert(numbered_list_params_to_ignore, tonumber(param))
					else
						table.insert(named_list_params_to_ignore,
							"^" .. require("Module:utilities").pattern_escape(param) .. "[0-9]*$")
					end
				else
					if rfind(ignore, "^[0-9]+$") then
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
						if rfind(k, lparam) then
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

	local args = m_params.process(parent_args, params, nil, "form of/templates", function_name)

	-- Tracking for certain user-specified params. This is generally used for
	-- parameters that we accept but ignore, so that we can eventually remove
	-- all uses of these params and stop accepting them.
	if tracked_params then
		for tracked_param, _ in pairs(tracked_params) do
			if parent_args[tracked_param] then
				track("arg/" .. tracked_param, template)
			end
		end
	end

	return args
end


-- Split TAGSPECS (inflection tag specifications) on SPLIT_REGEX, which
-- may be nil for no splitting.
local function split_inflection_tags(tagspecs, split_regex)
	if not split_regex then
		return tagspecs
	end
	local inflection_tags = {}
	for _, tagspec in ipairs(tagspecs) do
		for tag in rgsplit(tagspec, split_regex) do
			table.insert(inflection_tags, tag)
		end
	end
	return inflection_tags
end


local clitic_param_mods = {
	t = {
		-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "gloss",
	},
	gloss = {},
	tr = {},
	ts = {},
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
	sc = {
		convert = function(arg, parse_err)
			return require("Module:scripts").getByCode(arg, parse_err)
		end,
	}
}


local function parse_clitics(paramname, val, lang)
	local function generate_obj(term)
		return {lang = lang, term = term}
	end

	local retval
	-- Check for inline modifier, e.g. מרים<tr:Miryem>.
	if val:find("<") then
		retval = require(put_module).parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = clitic_param_mods,
			generate_obj = generate_obj,
			splitchar = ",",
		})
	else
        retval = rsplit(val, ",")
		for i, split in ipairs(retval) do
			retval[i] = generate_obj(split)
		end
	end

	return retval
end


local link_params = { "term", "alt", "t", "gloss", "sc", "tr", "ts", "pos", "g", "id", "lit" }
local link_param_set = {}
for _, param in ipairs(link_params) do
	link_param_set[param] = true
end

-- Modify PARAMS in-place by adding parameters that control the link to the
-- main entry. TERM_PARAM is the number of the param specifying the main
-- entry itself; TERM_PARAM + 1 will be the display text, and TERM_PARAM + 2
-- will be the gloss, unless NO_NUMBERED_GLOSS is given.
local function add_link_params(parent_args, params, term_param, no_numbered_gloss)
	-- See if any params for the second or higher term exist.
	local multiple_lemmas = false
	for k, v in pairs(parent_args) do
		if type(k) == "string" then
			local base, num = k:match("^([a-z]+)([0-9]+)$")
			if base and link_param_set[base] then
				multiple_lemmas = true
				break
			end
		end
	end
	-- If no params for the second or higher term exist, use a simpler param setup to save memory.
	params[term_param + 1] = {alias_of = "alt"}
	if not no_numbered_gloss then
		params[term_param + 2] = {alias_of = "t"}
	end
	if not multiple_lemmas then
		-- Numbered params controlling link display
		params[term_param] = {}

		-- Named params controlling link display
		params["gloss"] = {alias_of = "t"}
		params["g"] = {list = true}
		for _, param in ipairs(link_params) do
			if param ~= "gloss" and param ~= "g" and param ~= "term" then
				params[param] = {}
			end
		end
	else
		-- Numbered params controlling link display
		params[term_param] = { list = "term", allow_holes = true }

		-- Named params controlling link display
		params["gloss"] = { alias_of = "t", list = true, allow_holes = true }
		local list_spec = { list = true, allow_holes = true }
		for _, param in ipairs(link_params) do
			if param ~= "gloss" and param ~= "term" then
				params[param] = list_spec
			end
		end
	end

	return multiple_lemmas
end


--[=[
Given processed invocation arguments IARGS and processed parent arguments ARGS, as well as TERM_PARAM (the parent
argument specifying the first main entry/lemma), COMPAT (true if the language code is found in args["lang"] instead of
args[1]) and MULTIPLE_LEMMAS (true if there is more than one lemma, meaning that ARGS uses a different and more general
structure), return an object as follows:
{
	lang = LANG,
	lemmas = {LEMMA_OBJ, LEMMA_OBJ, ...},
	enclitics = {ENCLITIC_OBJ, ENCLITIC_OBJ, ...},
	categories = {"CATEGORY", "CATEGORY", ...},
}

where

* LANG is the language code;
* LEMMAS is a sequence of objects specifying the main entries/lemmas, as passed to full_link in [[Module:links]];
  however, if the invocation argument linktext= is given, it will be a string consisting of that text, and if the
  invocation argument nolink= is given, it will be nil;
* ENCLITICS is nil or a sequence of objects specifying the enclitics, as passed to full_link in [[Module:links]];
* CATEGORIES is the categories to add the page to (consisting of any categories specified in the invocation or
  parent args and any tracking categories, but not any additional lang-specific categories that may be added by
  {{inflection of}} or similar templates).

This is a subfunction of construct_form_of_text().
]=]
local function get_lemmas_and_categories(iargs, args, term_param, compat, multiple_lemmas)
	local lang = args[compat and "lang" or 1] or iargs["lang"] or "und"
	lang = require("Module:languages").getByCode(lang, compat and "lang" or 1)

	-- Determine categories for the page, including tracking categories

	local categories = {}

	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	for _, cat in ipairs(args["cat"]) do
		table.insert(categories, lang:getCanonicalName() .. " " .. cat)
	end

	-- Format the link, preceding text and categories

	local function add_term_tracking_categories(term)
		-- add tracking category if term is same as page title
		if term and mw.title.getCurrentTitle().text == (lang:makeEntryName(term)) then
			table.insert(categories, "Forms linking to themselves")
		end
		-- maybe add tracking category if primary entry doesn't exist (this is an
		-- expensive call so we don't do it by default)
		if iargs["noprimaryentrycat"] and term and mw.title.getCurrentTitle().nsText == ""
			and not mw.title.new(term).exists then
			table.insert(categories, lang:getCanonicalName() .. " " .. iargs["noprimaryentrycat"])
		end
	end

	local lemmas

	if iargs["nolink"] then
		lemmas = nil
	elseif iargs["linktext"] then
		lemmas = iargs["linktext"]
	elseif not multiple_lemmas then
		-- Only one lemma. We use a simpler structure in `args` to save memory.
		local term = args[term_param]

		if not term and not args["alt"] and not args["tr"] and not args["ts"] then
			if mw.title.getCurrentTitle().nsText == "Template" then
				term = "term"
			else
				error("No linked-to term specified; either specify term, alt, translit or transcription")
			end
		end

		add_term_tracking_categories(term)

		local sc = args["sc"] or iargs["sc"]

		sc = sc and require("Module:scripts").getByCode(sc, "sc") or nil

		local lemma_obj = {
			lang = lang,
			sc = sc,
			term = term,
			genders = args["g"],
			gloss = args["t"],
		}
		for _, param in ipairs(link_params) do
			if param ~= "sc" and param ~= "term" and param ~= "g" and param ~= "gloss" and param ~= "t" then
				lemma_obj[param] = args[param]
			end
		end
		lemmas = {lemma_obj}
	else
		lemmas = {}
		-- FIXME! Previously there was only one term parameter but multiple genders. For compatibility, if we see only
		-- one term but multiple genders, allow this and convert the genders to the new format, for further
		-- processing. Also track such usages so we can convert them.
		if args[term_param].maxindex <= 1 and args["g"].maxindex > 1 then
			local genders = {}
			for i = 1, args["g"].maxindex do
				if args["g"][i] then
					table.insert(genders, args["g"][i])
				end
			end
			args["g"] = {table.concat(genders, ",")}
			args["g"].maxindex = 1
			track("one-term-multiple-genders")
		end

		-- Find the maximum index among any of the list parameters.
		local maxmaxindex = 0
		for k, v in pairs(args) do
			if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
				maxmaxindex = v.maxindex
			end
		end

		for i = 1, maxmaxindex do
			local term = args[term_param][i]

			if not term and not args["alt"][i] and not args["tr"][i] and not args["ts"][i] then
				if i == 1 and mw.title.getCurrentTitle().nsText == "Template" then
					term = "term"
				else
					error("No linked-to term specified; either specify term, alt, translit or transcription")
				end
			end

			add_term_tracking_categories(term)

			local sc = args["sc"][i] or iargs["sc"]

			sc = sc and require("Module:scripts").getByCode(sc, "sc" .. (i == 1 and "" or i)) or nil

			local lemma_obj = {
				lang = lang,
				sc = sc,
				term = term,
				genders = args["g"][i] and rsplit(args["g"][i], ",") or {},
				gloss = args["t"][i],
			}
			for _, param in ipairs(link_params) do
				if param ~= "sc" and param ~= "term" and param ~= "g" and param ~= "gloss" and param ~= "t" then
					lemma_obj[param] = args[param][i]
				end
			end

			table.insert(lemmas, lemma_obj)
		end
	end

	local enclitics
	if args.enclitic then
		enclitics = parse_clitics("enclitic", args.enclitic, lang)
	end

	return {
		lang = lang,
		lemmas = lemmas,
		enclitics = enclitics,
		categories = categories,
	}
end


-- Construct and return the full definition line for a form-of-type template invocation, given processed invocation
-- arguments IARGS, processed parent arguments ARGS, TERM_PARAM (the parent argument specifying the main entry), COMPAT
-- (true if the language code is found in args["lang"] instead of args[1]), and DO_FORM_OF, which is a function that
-- returns the actual definition-line text and any language-specific categories. The terminating period/dot will be
-- added as appropriate, the language-specific categories will be added to any categories requested by the invocation
-- or parent args, and then whole thing will be appropriately formatted.
--
-- DO_FORM_OF takes one argument, the return value of get_lemmas_and_categories() (an object describing the lemmas,
-- clitics and categories fetched).
--
-- DO_FORM_OF should return two arguments:
--
-- (1) The actual definition-line text, marked up appropriately with <span>...</span> but without any terminating
--     period/dot.
-- (2) Any extra categories to add the page to (other than those that can be derived from parameters specified to the
--     invocation or parent arguments, which will automatically be added to the page).
local function construct_form_of_text(iargs, args, term_param, compat, multiple_lemmas, do_form_of)
	local lemma_data = get_lemmas_and_categories(iargs, args, term_param, compat, multiple_lemmas)

	local form_of_text, lang_cats = do_form_of(lemma_data)
	extend_list(lemma_data.categories, lang_cats)
	local text = form_of_text .. (
		args["nodot"] and "" or args["dot"] or iargs["withdot"] and "." or ""
	)
	if #lemma_data.categories == 0 then
		return text
	end
	return text .. require("Module:utilities").format_categories(lemma_data.categories, lemma_data.lang, args["sort"],
		nil, force_cat)
end


--[=[
Function that implements {{form of}} and the various more specific form-of
templates (but not {{inflection of}} or templates that take tagged inflection
parameters).

Invocation params:

1= (required):
	Text to display before the link.
term_param=:
	Numbered param holding the term linked to. Other numbered params come after.
	Defaults to 1 if invocation or template param lang= is present, otherwise 2.
lang=:
	Default language code for language-specific templates. If specified, no
	language code needs to be specified, and if specified it needs to be set
	using lang=, not 1=.
sc=:
	Default script code for language-specific templates. The script code can
	still be overridden using template param sc=.
cat=, cat2=, ...:
	Categories to place the page into. The language name will automatically be
	prepended. Note that there is also a template param cat= to specify
	categories at the template level. Use of nocat= disables categorization of
	categories specified using invocation param cat=, but not using template
	param cat=.
ignore=, ignore2=, ...:
	One or more template params to silently accept and ignore. Useful e.g. when
	the template takes additional parameters such as from= or POS=. Each value
	is a comma-separated list of either bare parameter names or specifications
	of the form "PARAM:list" to specify that the parameter is a list parameter.
def=, def2=, ...:
	One or more default values to supply for template args. For example,
	specifying '|def=tr=-' causes the default for template param '|tr=' to be
	'-'. Actual template params override these defaults.
withcap=:
	Capitalize the first character of the text preceding the link, unless
	template param nocap= is given.
withdot=:
	Add a final period after the link, unless template param nodot= is given
	to suppress the period, or dot= is given to specify an alternative
	punctuation character.
nolink=:
	Suppress the display of the link. If specified, none of the template
	params that control the link (TERM_PARAM, TERM_PARAM + 1, TERM_PARAM + 2,
	t=, gloss=, sc=, tr=, ts=, pos=, g=, id=, lit=) will be available.
	If the calling template uses any of these parameters, they must be
	ignored using ignore=.
linktext=:
	Override the display of the link with the specified text. This is useful
	if a custom template is available to format the link (e.g. in Hebrew,
	Chinese and Japanese). If specified, none of the template params that
	control the link (TERM_PARAM, TERM_PARAM + 1, TERM_PARAM + 2, t=, gloss=,
	sc=, tr=, ts=, pos=, g=, id=, lit=) will be available. If the calling
	template uses any of these parameters, they must be ignored using ignore=.
posttext=:
	Additional text to display directly after the formatted link, before any
	terminating period/dot and inside of "<span class='use-with-mention'>".
noprimaryentrycat=:
	Category to add the page to if the primary entry linked to doesn't exist.
	The language name will automatically be prepended.
]=]--
function export.form_of_t(frame)
	local iparams = {
		[1] = {required = true},
		["term_param"] = {type = "number"},
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["def"] = {list = true},
		["withcap"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["nolink"] = {type = "boolean"},
		["linktext"] = {},
		["posttext"] = {},
		["noprimaryentrycat"] = {},
	}

	local iargs = m_params.process(frame.args, iparams, nil, "form of/templates", "form_of_t")
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]

	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},

		-- Named params not controlling link display
		["cat"] = {list = true},
		["notext"] = {type = "boolean"},
		["sort"] = {},
		["enclitic"] = {},
		-- FIXME! The following should only be available when withcap=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nocap= in other circumstances.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
	}

	local multiple_lemmas
	if not iargs["nolink"] and not iargs["linktext"] then
		multiple_lemmas = add_link_params(parent_args, params, term_param)
	end

	if next(iargs["cat"]) then
		params["nocat"] = {type = "boolean"}
	end

	local ignored_params = {}

	if iargs["withdot"] then
		params["dot"] = {}
	else
		ignored_params["nodot"] = true
	end

	if not iargs["withcap"] then
		params["cap"] = {type = "boolean"}
		ignored_params["nocap"] = true
	end

	local args = process_parent_args("form-of-t", parent_args, params, iargs["def"],
		iargs["ignore"], ignored_params, "form_of_t")

	local text = args["notext"] and "" or iargs[1]
	if args["cap"] or iargs["withcap"] and not args["nocap"] then
		text = require("Module:string utilities").ucfirst(text)
	end

	return construct_form_of_text(iargs, args, term_param, compat, multiple_lemmas,
		function(lemma_data)
			return m_form_of.format_form_of {text = text, lemmas = lemma_data.lemmas,
				enclitics = lemma_data.enclitics, lemma_face = "term", posttext = iargs["posttext"]}, {}
		end
	)
end


--[=[
Construct and return the full definition line for a form-of-type template invocation that is based on inflection tags.
This is a wrapper around construct_form_of_text() and takes the following arguments: processed invocation arguments
IARGS, processed parent arguments ARGS, TERM_PARAM (the parent argument specifying the main entry), COMPAT (true if the
language code is found in args["lang"] instead of args[1]), and TAGS, the list of (non-canonicalized) inflection tags.
It returns that actual definition-line text including terminating period/full-stop, formatted categories, etc. and
should be directly returned as the template function's return value. JOINER is the strategy to join multipart tags for
display; currently accepted values are "and", "slash", "en-dash".
]=]
local function construct_tagged_form_of_text(iargs, args, term_param, compat, multiple_lemmas, tags, joiner)
	return construct_form_of_text(iargs, args, term_param, compat, multiple_lemmas,
		function(lemma_data)
			-- NOTE: tagged_inflections returns two values, so we do too.
			return m_form_of.tagged_inflections {
				lang = lemma_data.lang,
				tags = tags,
				lemmas = lemma_data.lemmas,
				enclitics = lemma_data.enclitics,
				lemma_face = "term",
				POS = args["p"],
				-- Set no_format_categories because we do it ourselves in construct_form_of_text().
				no_format_categories = true,
				nocat = args["nocat"],
				notext = args["notext"],
				capfirst = args["cap"] or iargs["withcap"] and not args["nocap"],
				posttext = iargs["posttext"],
				joiner = joiner,
			}
		end
	)
end


--[=[
Function that implements form-of templates that are defined by specific tagged inflections (typically a template
referring to a non-lemma inflection, such as {{plural of}}). This works exactly like form_of_t() except that the
"form of" text displayed before the link is based off of a pre-specified set of inflection tags (which will be
appropriately linked to the glossary) instead of arbitrary text. From the user's perspective, there is no difference
between templates implemented using form_of_t() and tagged_form_of_t(); they accept exactly the same parameters and
work the same. See also inflection_of_t() below, which is intended for templates with user-specified inflection tags.

Invocation params:

1=, 2=, ... (required):
	One or more inflection tags describing the inflection in question.
split_tags=:
	If specified, character to split specified inflection tags on. This allows
	multiple tags to be included in a single argument, simplifying template
	code.
term_param=:
lang=:
sc=:
cat=, cat2=, ...:
ignore=, ignore2=, ...:
def=, def2=, ...:
withcap=:
withdot=:
nolink=:
linktext=:
posttext=:
noprimaryentrycat=:
	All of these are the same as in form_of_t().
]=]--
function export.tagged_form_of_t(frame)
	local iparams = {
		[1] = {list = true, required = true},
		["split_tags"] = {},
		["term_param"] = {type = "number"},
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["def"] = {list = true},
		["withcap"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["nolink"] = {type = "boolean"},
		["linktext"] = {},
		["posttext"] = {},
		["noprimaryentrycat"] = {},
	}

	local iargs = m_params.process(frame.args, iparams, nil, "form of/templates", "tagged_form_of_t")
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]

	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},

		-- Named params not controlling link display
		["cat"] = {list = true},
		-- Always included because lang-specific categories may be added
		["nocat"] = {type = "boolean"},
		["p"] = {},
		["POS"] = {alias_of = "p"},
		["notext"] = {type = "boolean"},
		["sort"] = {},
		["enclitic"] = {},
		-- FIXME! The following should only be available when withcap=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nocap= in other circumstances.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
	}

	local multiple_lemmas
	if not iargs["nolink"] and not iargs["linktext"] then
		multiple_lemmas = add_link_params(parent_args, params, term_param)
	end

	local ignored_params = {}

	if iargs["withdot"] then
		params["dot"] = {}
	else
		ignored_params["nodot"] = true
	end

	if not iargs["withcap"] then
		params["cap"] = {type = "boolean"}
		ignored_params["nocap"] = true
	end

	local args = process_parent_args("tagged-form-of-t", parent_args,
		params, iargs["def"], iargs["ignore"], ignored_params, "tagged_form_of_t")

	return construct_tagged_form_of_text(iargs, args, term_param, compat, multiple_lemmas,
		split_inflection_tags(iargs[1], iargs["split_tags"]), "and")
end

--[=[
Function that implements {{inflection of}} and certain semi-specific variants,
such as {{participle of}} and {{past participle form of}}. This function is
intended for templates that allow the user to specify a set of inflection tags.
It works similarly to form_of_t() and tagged_form_of_t() except that the
calling convention for the calling template is
	{{TEMPLATE|LANG|MAIN_ENTRY_LINK|MAIN_ENTRY_DISPLAY_TEXT|TAG|TAG|...}}
instead of 
	{{TEMPLATE|LANG|MAIN_ENTRY_LINK|MAIN_ENTRY_DISPLAY_TEXT|GLOSS}}
Note that there isn't a numbered parameter for the gloss, but it can still
be specified using t= or gloss=.

Invocation params:

preinfl=, preinfl2=, ...:
	Extra inflection tags to automatically prepend to the tags specified by
	the template.
postinfl=, postinfl2=, ...:
	Extra inflection tags to automatically append to the tags specified by the
	template. Used for example by {{past participle form of}} to add the tags
	'of the|past|p' onto the user-specified tags, which indicate which past
	participle form the page refers to.
split_tags=:
	If specified, character to split specified inflection tags on. This allows
	multiple tags to be included in a single argument, simplifying template
	code. Note that this applies *ONLY* to inflection tags specified in the
	invocation arguments using preinfl= or postinfl=, not to user-specified
	inflection tags.
term_param=:
lang=:
sc=:
cat=, cat2=, ...:
ignore=, ignore2=, ...:
def=, def2=, ...:
withcap=:
withdot=:
nolink=:
linktext=:
posttext=:
noprimaryentrycat=:
	All of these are the same as in form_of_t().
]=]--
function export.inflection_of_t(frame)
	local iparams = {
		["preinfl"] = {list = true},
		["postinfl"] = {list = true},
		["split_tags"] = {},
		["term_param"] = {type = "number"},
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["def"] = {list = true},
		["withcap"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["nolink"] = {type = "boolean"},
		["linktext"] = {},
		["posttext"] = {},
		["noprimaryentrycat"] = {},
	}

	local iargs = m_params.process(frame.args, iparams, nil, "form of/templates", "inflection_of_t")
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]

	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2
	local tagsind = term_param + 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		[tagsind] = {list = true,
			-- at least one inflection tag is required unless preinfl or
			-- postinfl tags are given
			required = #iargs["preinfl"] == 0 and #iargs["postinfl"] == 0},

		-- Named params not controlling link display
		["cat"] = {list = true},
		-- Always included because lang-specific categories may be added
		["nocat"] = {type = "boolean"},
		["p"] = {},
		["POS"] = {alias_of = "p"},
		["notext"] = {type = "boolean"},
		["enclitic"] = {},
		["sort"] = {},
		-- FIXME! The following should only be available when withcap=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nocap= in other circumstances.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		-- Temporary, allows multipart joiner to be controlled on a template-by-template
		-- basis
		["joiner"] = {},
	}

	local multiple_lemmas
	if not iargs["nolink"] and not iargs["linktext"] then
		multiple_lemmas = add_link_params(parent_args, params, term_param, "no-numbered-gloss")
	end

	local ignored_params = {}

	if iargs["withdot"] then
		params["dot"] = {}
	else
		ignored_params["nodot"] = true
	end

	if not iargs["withcap"] then
		params["cap"] = {type = "boolean"}
		ignored_params["nocap"] = true
	end

	local args = process_parent_args("inflection-of-t", parent_args,
		params, iargs["def"], iargs["ignore"], ignored_params, "inflection_of_t")

	local infls
	if not next(iargs["preinfl"]) and not next(iargs["postinfl"]) then
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
		local split_preinfl = split_inflection_tags(iargs["preinfl"], iargs["split_tags"])
		local split_postinfl = split_inflection_tags(iargs["postinfl"], iargs["split_tags"])
		if not saw_semicolon then
			extend_list(infls, split_preinfl)
			extend_list(infls, args[tagsind])
			extend_list(infls, split_postinfl)
		else
			local groups = m_form_of.split_tags_into_tag_sets(args[tagsind])
			for _, group in ipairs(groups) do
				if #infls > 0 then
					table.insert(infls, ";")
				end
				extend_list(infls, split_preinfl)
				extend_list(infls, group)
				extend_list(infls, split_postinfl)
			end
		end
	end

	return construct_tagged_form_of_text(iargs, args, term_param, compat, multiple_lemmas, infls,
		parent_args["joiner"])
end

--[=[
Normalize a part-of-speech tag given a possible abbreviation
(passed in as 1= of the invocation args). If the abbreviation
isn't recognized, the original POS tag is returned. If no POS
tag is passed in, return the value of invocation arg default=.
]=]--
function export.normalize_pos(frame)
	local iparams = {
		[1] = {},
		["default"] = {},
	}
	local iargs = m_params.process(frame.args, iparams, nil, "form of/templates", "normalize_pos")
	if not iargs[1] and not iargs["default"] then
		error("Either 1= or default= must be given in the invocation args")
	end
	return m_form_of_pos[iargs[1]] or iargs[1] or iargs["default"]
end

return export
