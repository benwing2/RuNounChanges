local export = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

--[=[
Function that implements specific form-of tags that refer to a non-lemma inflection,
such as {{genitive plural of}}.

Invocation params:

1=, 2=, ... (required):
	One or more inflection tags describing the inflection in question.
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
]=]--
function export.template_tags(frame)
	local iparams = {
		[1] = {list = true, required = true},
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local compat = iargs["lang"] or frame:getParent().args["lang"]
	local offset = compat and 0 or 1

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		[1 + offset] = {required = true},
		[2 + offset] = {},
		[3 + offset] = {alias_of = "t"},

		-- Named params not controlling link display		
		["nodot"] = {type = "boolean"},  -- does nothing right now, but used in existing entries
		["cat"] = {list = true},
		["sort"] = {},

		-- Named params controlling link display
		["t"] = {},
		["gloss"] = {alias_of = "t"},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
		["pos"] = {},
		["g"] = {list = true},
		["id"] = {},
		["lit"] = {},
	}
	
	if next(iargs["cat"]) then
		params["nocat"] = {type = "boolean"}
	end
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = iargs["lang"] or args[compat and "lang" or 1] or "und"
	local sc = args["sc"] or iargs["sc"]
	
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	local categories = {}
	
	if #iargs[1] == 1 and iargs[1][1] == "f" then
		require("Module:debug").track("feminine of/" .. lang:getCode())
	end
	
	local ret = require("Module:form of").tagged_inflections(iargs[1],
		{lang = lang, sc = sc, term = args[1 + offset] or "term", alt = args[2 + offset],
		 id = args["id"], lit = args["lit"], gloss = args["t"], pos = args["pos"],
		 genders = args["g"], tr = args["tr"], ts = args["ts"]})
	
	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	for _, cat in ipairs(args["cat"]) do
		table.insert(categories, lang:getCanonicalName() .. " " .. cat)
	end

	-- some pre-existing tracking code we should probably delete
	if next(iargs["cat"]) then
		if args["nocat"] then
			require("Module:debug").track("form of/" .. table.concat(iargs[1], "-") .. "/nocat")
		else
			require("Module:debug").track("form of/" .. table.concat(iargs[1], "-") .. "/cat")
		end
	end
	
	return ret .. require("Module:utilities").format_categories(categories, lang, args["sort"])
end

--[=[
Function that implements {{form of}} and the various more specific form-of templates.

Invocation params:

1= (required):
	Text to display before the link.
term_param=:
	Numbered param holding the term linked to. Other numbered params come after.
	Defaults to 2. Note that the language code is always in param 1=. This param
	will automatically be adjusted down by one if lang= is used to encode the language 
	code.
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
		["term_param"] = {type = "number", default = 2},
		["lang"] = {},
		["sc"] = {},
		["id"] = {},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["withcap"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["noprimaryentrycat"] = {},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]
	
	local categories = {}

	local compat = iargs["lang"] or parent_args["lang"]
	local offset = compat and -1 or 0

	local function track(page)
		require("Module:debug").track("form-of/form-of-t/" .. page)
	end

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		[term_param + offset] = {},
		[term_param + offset + 1] = {},
		[term_param + offset + 2] = {alias_of = "t"},
		
		-- Named params not controlling link display		
		-- For now, we always allow this even when withcap=1 is not given
		-- because many templates process nocap= manually.
		["nocap"] = {type = "boolean"},
		["cat"] = {list = true},
		-- FIXME! The following should only be available when withdot=1 in
		-- invocation args. Before doing that, need to remove all uses of
		-- nodot= in other circumstances.
		["nodot"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
		["sort"] = {},

		-- Named params controlling link display
		["t"] = {},
		["gloss"] = {alias_of = "t"},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
		["pos"] = {},
		["g"] = {list = true},
		["id"] = {},
		["lit"] = {},
	}

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

	for _, ignore in ipairs(iargs["ignore"]) do
		local paramname = nil
		for i, ignorespec in ipairs(rsplit(ignore, ":")) do
			if i == 1 then
				paramname = ignorespec
				if rfind(paramname, "^[0-9]+$") then
					paramname = tonumber(paramname)
				end
				params[paramname] = {}
				ignored_params[paramname] = nil
			elseif ignorespec == "required" then
				params[paramname]["required"] = true
			elseif ignorespec == "list" then
				params[paramname]["list"] = true
			else
				local paramtype = rmatch(ignorespec, "^type=(.*)$")
				if paramtype then
					params[paramname]["type"] = paramtype
				else
					error("Unrecognized ignore spec: " .. ignorespec)
				end
			end
		end
	end
	
	local args = require("Module:parameters").process(parent_args, params)

	-- temporary tracking for valid but unused arguments not in ignore=
	for unused_arg, _ in pairs(ignored_params) do
		if parent_args[unused_arg] then
			track("unused")
			track("unused/" .. unused_arg)
		end
	end

	local text = args["notext"] and "" or iargs[1]
	if iargs["withcap"] and not args["nocap"] then
		text = mw.ustring.upper(mw.ustring.sub(text, 1, 1)) .. mw.ustring.sub(text, 2)
	end

	local term = args[term_param + offset]
	local alt = args[term_param + offset + 1]

	if not term and not alt and not args["tr"] and not args["ts"] then
		if mw.title.getCurrentTitle().nsText == "Template" then
			term = "term"
		else
			error("No linked-to term specified; either specify term, alt, translit or transcription")
		end
	end
	
	local lang = args[compat and "lang" or 1] or iargs["lang"] or "und"
	local sc = args["sc"] or iargs["sc"]
	local id = args["id"] or iargs["id"]
	
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	-- Determine categories for the page, including tracking categories

	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	for _, cat in ipairs(args["cat"]) do
		table.insert(categories, lang:getCanonicalName() .. " " .. cat)
	end
	-- add tracking category if term is same as page title
	if term and mw.title.getCurrentTitle().text == lang:makeEntryName(term) then
		table.insert(categories, "Forms linking to themselves")
	end
	-- maybe add tracking category if primary entry doesn't exist (this is an
	-- expensive call so we don't do it by default)
	if iargs["noprimaryentrycat"] and term and mw.title.getCurrentTitle().nsText == ""
		-- FIXME, use the right call
		and not mw.title.getCurrentTitle().exists then
		table.insert(categories, lang:getCanonicalName() .. " " .. iargs["noprimaryentrycat"])
	end
		
	-- Format the link, preceding text and categories

	return require("Module:form of").format_form_of(text,
		{
			lang = lang,
			sc = sc,
			term = term,
			alt = alt,
			id = id,
			gloss = args["t"],
			tr = args["tr"],
			ts = args["ts"],
			pos = args["pos"],
			genders = args["g"],
			lit = args["lit"],
		}
	) .. (args["nodot"] and "" or args["dot"] or iargs["withdot"] and "." or "") require("Module:utilities").format_categories(categories, lang, args["sort"])
end

--[=[
Function that implements {{inflection of}} and certain semi-specific variants, such as
{{past participle form of}}.

Invocation params:

1=:
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
preinfl=, preinfl2=, ...:
	Extra inflection tags to automatically prepend to the tags specified by the template.
postinfl=, postinfl2=, ...:
	Extra inflection tags to automatically append to the tags specified by the template. Used for example by {{past participle form of}} to add the tags 'of the|past|p'
	onto the template-specified tags, which indicate which past participle form the
	page refers to.
]=]--
function export.inflection_of_t(frame)
	local iparams = {
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
		["preinfl"] = {list = true},
		["postinfl"] = {list = true},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local compat = iargs["lang"] or parent_args["lang"]
	local offset = compat and 0 or 1

	local params = {
		-- Numbered params
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		[1 + offset] = {required = true},
		[2 + offset] = {},
		[3 + offset] = {list = true, required = true},
		
		-- Named params not controlling link display		
		-- FIXME! The following should not be allowed. Before doing that, need to
		remove all uses of nocap=.
		["nocap"] = {type = "boolean"},
		-- FIXME! The following should only be available when cat= is specified
		-- in the invocation args. Before doing that, need to remove all uses of
		-- nocat= in other circumstances.
		["nocat"] = {type = "boolean"},
		["cat"] = {list = true},
		-- FIXME! The following should not be allowed. Before doing that, need to
		remove all uses of nodot=.
		["nodot"] = {type = "boolean"},
		["sort"] = {},

		-- Named params controlling link display
		["t"] = {},
		["gloss"] = {alias_of = "t"},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
		["pos"] = {},
		["g"] = {list = true},
		["id"] = {},
		["lit"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[compat and "lang" or 1] or iargs["lang"] or "und"
	local sc = args["sc"] or iargs["sc"]
	
	lang = require("Module:languages").getByCode(lang) or
		require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or
		error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	local categories = {}

	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	for _, cat in ipairs(args["cat"]) do
		table.insert(categories, lang:getCanonicalName() .. " " .. cat)
	end

	local infls
	if not next(iargs["preinfl"]) and not next(iargs["postinfl"]) then
		infls = args[3 + offset]
	else
		infls = {}
		for _, infl in ipairs(iargs["preinfl"]) do
			table.insert(infls, infl)
		end
		for _, infl in ipairs(args[3 + offset]) do
			table.insert(infls, infl)
		end
		for _, infl in ipairs(iargs["postinfl"]) do
			table.insert(infls, infl)
		end
	end
	
	return require("Module:form of").tagged_inflections(
		infls,
		{
			lang = lang,
			sc = sc,
			term = args[1 + offset] or "term",
			alt = args[2 + offset],
			id = args["id"],
			lit = args["lit"],
			gloss = args["t"],
			pos = args["pos"],
			genders = args["g"],
			tr = args["tr"],
			ts = args["ts"],
		}
	) .. require("Module:utilities").format_categories(categories, lang, args["sort"])
end

return export
