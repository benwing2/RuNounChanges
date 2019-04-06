local export = {}

local m_form_of = require("Module:form of")
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local function track(template, page)
	require("Module:debug").track("form-of/" .. template .. "/" .. page)
end

local function process_parent_args(template, parent_args, params, defaults, ignorespecs, ignored_params)
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

		local 

		for _, ignorespec in ipairs(ignorespecs) do
			for _, ignore in rsplit(ignorespec, ",") do
				param = rmatch(ignore, "^(.*):list$")
				if param then
					if rfind(param, "^[0-9]+$") then
						table.insert(numbered_list_params_to_ignore, tonumber(param))
					else
						table.insert(named_list_params_to_ignore, "^" .. param .. "[0-9]*$")
					end
				else
					if rfind(ignore, "^[0-9]+$") then
						ignore = tonumber(ignore)
					end
					params_to_ignore[ignore] = true
				end
			end
		end

		for k, v in ipairs(parent_args) do
			if params_to_ignore[k] then
				continue
			end
			local ignore_me = false
			if type(k) == "number" then
				for _, lparam in ipairs(numbered_list_params_to_ignore) do
					if k >= lparam then
						ignore_me = true
						break
					end
				end
			else
				local ignore_me = false
				for _, lparam in ipairs(named_list_params_to_ignore) do
					if rfind(k, lparam) then
						ignore_me = true
						break
					end
				end
			end
			if ignore_me then
				continue
			end
			new_parent_args[k] = v
		end

	local args = require("Module:parameters").process(parent_args, params)

	-- temporary tracking for valid but unused arguments not in ignore=
	if ignored_params then
		for unused_arg, _ in pairs(ignored_params) do
			if parent_args[unused_arg] then
				track(template, "unused")
				track(template, "unused/" .. unused_arg)
			end
		end
	end

	return args
end

local function split_inflection_tags(tagspecs, split_regex)
	if not split_regex then
		return tagspecs
	end
	local inflection_tags = {}
	for _, tagspec in ipairs(tagspecs) do
		for _, tag in ipairs(rsplit(tagspec, split_regex)) do
			table.insert(inflection_tags, tag)
		end
	end
	return inflection_tags
end


local function add_link_params(params, term_param, no_numbered_gloss)
	-- Numbered params controlling link display
	params[term_param] = {}
	params[term_param + 1] = {}
	if not no_numbered_gloss then
		params[term_param + 2] = {alias_of = "t"}
	end
	
	-- Named params controlling link display
	params["t"] = {}
	params["gloss"] = {alias_of = "t"}
	params["sc"] = {}
	params["tr"] = {}
	params["ts"] = {}
	params["pos"] = {}
	params["g"] = {list = true}
	params["id"] = {}
	params["lit"] = {}
end


local function get_terminfo_and_categories(iargs, args, term_param, compat)
	local lang = args[compat and "lang" or 1] or iargs["lang"] or "und"
	lang = require("Module:languages").getByCode(lang) or
		require("Module:languages").err(lang, compat and "lang" or 1)

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

	local terminfo

	if iargs["nolink"] then
		terminfo = nil
	elseif iargs["linktext"] then
		terminfo = iargs["linktext"]
	else
		local term = args[term_param]

		if not term and not args[term_param + 1] and not args["tr"] and not args["ts"] then
			if mw.title.getCurrentTitle().nsText == "Template" then
				term = "term"
			else
				error("No linked-to term specified; either specify term, alt, translit or transcription")
			end
		end
		
		-- add tracking category if term is same as page title
		if term and mw.title.getCurrentTitle().text == lang:makeEntryName(term) then
			table.insert(categories, "Forms linking to themselves")
		end
		-- maybe add tracking category if primary entry doesn't exist (this is an
		-- expensive call so we don't do it by default)
		if iargs["noprimaryentrycat"] and term and mw.title.getCurrentTitle().nsText == ""
			and not mw.title.new(term).exists then
			table.insert(categories, lang:getCanonicalName() .. " " .. iargs["noprimaryentrycat"])
		end

		local sc = args["sc"] or iargs["sc"]
		
		sc = (sc and (require("Module:scripts").getByCode(sc) or
			error("The script code \"" .. sc .. "\" is not valid.")) or nil)

		terminfo = {
			lang = lang,
			sc = sc,
			term = term,
			alt = args[term_param + 1],
			id = args["id"],
			gloss = args["t"],
			tr = args["tr"],
			ts = args["ts"],
			pos = args["pos"],
			genders = args["g"],
			lit = args["lit"],
		}
	end
	
	return lang, terminfo, categories
end


--[=[
Function that implements {{form of}} and the various more specific form-of templates.

Invocation params:

1= (required):
	Text to display before the link.
term_param=:
	Numbered param holding the term linked to. Other numbered params come after.
	Defaults to 1 if invocation or template param lang= is present, otherwise 2.
lang=:
	Default language code for language-specific templates. If specified, the term
	param moves down to 1= and no language code needs to be specified. (Currently
	it can still be specified using template param lang=, and overrides the default
	language code, but this may change.)
sc=:
	Default script code for language-specific templates. The script code can still be
	overridden using template param sc=.
id=:
	Default value of template param id=, which can still be specified. This param may
	be removed in the future, perhaps in favor of a more general default-value param.
cat=, cat2=, ...:
	Categories to place the page into. The language name will automatically be prepended.
	Note that there is also a template param cat= to specify categories at the template
	level. use of nocat= disables categorization of categories specified using invocation
	param cat=, but not using template param cat=.
ignore=, ignore2=, ...:
	One or more template params to silently accept and ignore. Useful e.g. when the
	template takes additional parameters such as from= or POS=. The value is a parameter
	name, optionally followed by one or more specs. Possible specs are ':list'
	(the param is a list parameter), ':required' (the param is required), and
	':type=TYPE' (specify the type of the param, e.g. "boolean" or "number").
	For example, to accept and ignore a from= list-type parameter, use '|ignore=from:list'.
def=, def2=, ...:
	One or more default values to supply for template args. For example, specifying
	'|def=tr=-' causes the default for template param '|tr=' to be '-'. Actual template
	params override these defaults.
withcap=:
	Capitalize the first character of the text preceding the link, unless template param
	nocap= is given.
withdot=:
	Add a final period after the link, unless template param nodot= is given to suppress
	the period, or dot= is given to specify an alternative punctuation character.
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
		["noprimaryentrycat"] = {},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]
	
	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		
		-- Named params not controlling link display		
		-- For now, we always allow this even when withcap=1 is not given
		-- because many templates process nocap= manually.
		["nocap"] = {type = "boolean"},
		["cat"] = {list = true},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		["sort"] = {},
	}

	if not iargs["nolink"] and not iargs["linktext"] then
		add_link_params(params, term_param)
	end

	if next(iargs["cat"]) then
		params["nocat"] = {type = "boolean"}
	end

	if iargs["withdot"] then
		params["dot"] = {}
	end

	local ignored_params = {}
	if not iargs["withdot"] then
		ignored_params["nodot"] = true
	end

	local args = process_parent_args("form-of-t", parent_args, params, iargs["def"],
		iargs["ignore"], ignored_params)
	
	local text = iargs[1]
	if iargs["withcap"] and not args["nocap"] then
		text = m_form_of.ucfirst(text)
	end

	local lang, terminfo, categories = get_terminfo_and_categories(iargs, args, term_param, compat)

	return m_form_of.format_form_of(text, terminfo) .. (
		args["nodot"] and "" or args["dot"] or iargs["withdot"] and "." or ""
	) .. require("Module:utilities").format_categories(categories, lang, args["sort"])
end

--[=[
Function that implements form-of templates that are defined by specific tagged
inflections (typically a template referring to a non-lemma inflection,
such as {{genitive plural of}}). It is equivalent to {{inflection of}} with
pre-specified inflection tags. See also inflection_of_t below, which is intended
for templates with user-specified inflection tags.

Invocation params:

1=, 2=, ... (required):
	One or more inflection tags describing the inflection in question.
term_param=:
	Numbered param holding the term linked to. Other numbered params come after.
	Defaults to 1 if invocation or template param lang= is present, otherwise 2.
lang=:
	Default language code for language-specific templates. If specified, the term
	param moves down to 1= and no language code needs to be specified. (Currently
	it can still be specified using template param lang=, and overrides the default
	language code, but this may change.)
sc=:
	Default script code for language-specific templates. The script code can still be
	overridden using template param sc=.
cat=, cat2=, ...:
	Categories to place the page into. The language name will automatically be prepended.
	Note that there is also a template param cat= to specify categories at the template
	level. use of nocat= disables categorization of categories specified using invocation
	param cat=, but not using template param cat=.
ignore=, ignore2=, ...:
	One or more template params to silently accept and ignore. Useful e.g. when the
	template takes additional parameters such as from= or POS=. The value is a parameter
	name, optionally followed by one or more specs. Possible specs are ':list'
	(the param is a list parameter), ':required' (the param is required), and
	':type=TYPE' (specify the type of the param, e.g. "boolean" or "number").
	For example, to accept and ignore a from= list-type parameter, use '|ignore=from:list'.
def=, def2=, ...:
	One or more default values to supply for template args. For example, specifying
	'|def=tr=-' causes the default for template param '|tr=' to be '-'. Actual template
	params override these defaults.
withcap=:
	Capitalize the first character of the text preceding the link, unless template param
	nocap= is given.
withdot=:
	Add a final period after the link, unless template param nodot= is given to suppress
	the period, or dot= is given to specify an alternative punctuation character.
split_tags=:
	If specified, character to split specified inflection tags on. This allows
	multiple tags to be included in a single argument, simplifying template code.
]=]--
function export.tagged_form_of_t(frame)
	local iparams = {
		[1] = {list = true, required = true},
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
		["noprimaryentrycat"] = {},
		["split_tags"] = {},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]

	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},

		-- Named params not controlling link display		
		-- For now, we always allow this even when withcap=1 is not given
		-- because many templates process nocap= manually.
		["nocap"] = {type = "boolean"},
		["cat"] = {list = true},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		["sort"] = {},
	}
	
	if not iargs["nolink"] and not iargs["linktext"] then
		add_link_params(params, term_param)
	end

	if next(iargs["cat"]) then
		params["nocat"] = {type = "boolean"}
	end
	
	if iargs["withdot"] then
		params["dot"] = {}
	end

	local ignored_params = {}
	if not iargs["withdot"] then
		ignored_params["nodot"] = true
	end

	local args = process_parent_args("tagged-form-of-t", parent_args,
		params, iargs["def"], iargs["ignore"], ignored_params)
	
	local lang, terminfo, categories = get_terminfo_and_categories(iargs, args, term_param, compat)

	return m_form_of.tagged_inflections(
		split_inflection_tags(iargs[1], iargs["split_tags"]), terminfo,
		iargs["withcap"] and not args["nocap"]
	) .. (args["nodot"] and "" or args["dot"] or iargs["withdot"] and "." or "")
	.. require("Module:utilities").format_categories(categories, lang, args["sort"])
end

--[=[
Function that implements {{inflection of}} and certain semi-specific variants, such as
{{past participle form of}}.

Invocation params:

term_param=:
	Numbered param holding the term linked to. Other numbered params come after.
	Defaults to 1 if invocation or template param lang= is present, otherwise 2.
lang=:
	Default language code for language-specific templates. If specified, the term
	param moves down to 1= and no language code needs to be specified. (Currently
	it can still be specified using template param lang=, and overrides the default
	language code, but this may change.)
sc=:
	Default script code for language-specific templates. The script code can still be
	overridden using template param sc=.
cat=, cat2=, ...:
	Categories to place the page into. The language name will automatically be prepended.
	Note that there is also a template param cat= to specify categories at the template
	level. use of nocat= disables categorization of categories specified using invocation
	param cat=, but not using template param cat=.
ignore=, ignore2=, ...:
	One or more template params to silently accept and ignore. Useful e.g. when the
	template takes additional parameters such as from= or POS=. The value is a parameter
	name, optionally followed by one or more specs. Possible specs are ':list'
	(the param is a list parameter), ':required' (the param is required), and
	':type=TYPE' (specify the type of the param, e.g. "boolean" or "number").
	For example, to accept and ignore a from= list-type parameter, use '|ignore=from:list'.
def=, def2=, ...:
	One or more default values to supply for template args. For example, specifying
	'|def=tr=-' causes the default for template param '|tr=' to be '-'. Actual template
	params override these defaults.
preinfl=, preinfl2=, ...:
	Extra inflection tags to automatically prepend to the tags specified by the template.
postinfl=, postinfl2=, ...:
	Extra inflection tags to automatically append to the tags specified by the template. Used for example by {{past participle form of}} to add the tags 'of the|past|p'
	onto the template-specified tags, which indicate which past participle form the
	page refers to.
split_tags=:
	If specified, character on which to split inflection tags specified by
	prefinfl= and postinfl=. This allows ultiple tags to be included in a single
	argument, simplifying template code.
]=]--
function export.inflection_of_t(frame)
	local iparams = {
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
		["preinfl"] = {list = true},
		["postinfl"] = {list = true},
		["split_tags"] = {},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]
	
	local compat = iargs["lang"] or parent_args["lang"]
	term_param = term_param or compat and 1 or 2

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		[term_param + 2] = {list = true, required = true},
		
		-- Named params not controlling link display		
		-- For now, we always allow this even when withcap=1 is not given
		-- because many templates process nocap= manually.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when cat= is specified
		-- in the invocation args. Before doing that, need to remove all uses of
		-- nocat= in other circumstances.
		["nocat"] = {type = "boolean"},
		["cat"] = {list = true},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		["sort"] = {},
	}
	
	if not iargs["nolink"] and not iargs["linktext"] then
		add_link_params(params, term_param, "no-numbered-gloss")
	end

	local ignored_params = {
		["nocap"] = true,
		["nodot"] = true,
	}
	if not next(iargs["cat"]) then
		ignored_params["nocat"] = true
	end

	local args = process_parent_args("inflection-of-t", parent_args,
		params, iargs["def"], iargs["ignore"], ignored_params)
	
	local infls
	if not next(iargs["preinfl"]) and not next(iargs["postinfl"]) then
		infls = args[term_param + 2]
	else
		infls = {}
		for _, infl in ipairs(split_inflection_tags(iargs["preinfl"], iargs["split_tags"])) do
			table.insert(infls, infl)
		end
		for _, infl in ipairs(args[term_param + 2]) do
			table.insert(infls, infl)
		end
		for _, infl in ipairs(split_inflection_tags(iargs["postinfl"], iargs["split_tags"])) do
			table.insert(infls, infl)
		end
	end

	local lang, terminfo, categories = get_terminfo_and_categories(iargs, args, term_param, compat)
	
	return m_form_of.tagged_inflections(infls, terminfo,
		iargs["withcap"] and not args["nocap"]
	) .. (args["nodot"] and "" or args["dot"] or iargs["withdot"] and "." or "")
	.. require("Module:utilities").format_categories(categories, lang, args["sort"])
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
