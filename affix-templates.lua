local export = {}

local m_affix = require("Module:affix")
local parameter_utilities_module = "Module:parameter utilities"
local pseudo_loan_module = "Module:affix/pseudo-loan"


local function is_property_key(k)
	return require(parameter_utilities_module).item_key_is_property(k)
end


-- Parse raw arguments. A single parameter `data` is passed in, with the following fields:
-- * `raw_args`: The raw arguments to parse, normally taken from `frame:getParent().args`.
-- * `extra_params`: An optional function of one argument that is called on the `params` structure before parsing; its
--   purpose is to specify additional allowed parameters or possibly disable parameters.
-- * `has_source`: There is a source-language parameter following 1= (which becomes the "destination" language
--   parameter) and preceding the terms. This is currently used for {{pseudo-loan}}.
-- * `ilang`: If given, it is a language object that serves as the default for the language. If specified, there is no
--   language code specified in 1=; instead the term parameters start directly at 1= (or at 2= if `has_source` is
--   given).
-- * `require_index_for_pos`: There is no separate |pos= parameter distinct from |pos1=, |pos2=, etc. Instead,
--   specifying |pos= results in an error.
--
-- Note that all language parameters are allowed to be etymology-only languages.
--
-- Return five values ARGS, ITEMS, LANG_OBJ, SCRIPT_OBJ, SOURCE_LANG_OBJ where ARGS is a table of the parsed arguments;
-- ITEMS is the list of parsed items; LANG_OBJ is the language object corresponding to the language code specified in 1=
-- (or taken from `ilang` if given); SCRIPT_OBJ is the script object corresponding to sc= (if given, otherwise nil); and
-- SOURCE_LANG_OBJ is the language object corresponding to the source-language code specified in 2= (or 1= if `ilang` is
-- given) if `has_source` is specified (otherwise nil).
local function parse_args(data)
	local raw_args = data.raw_args
	local has_source = data.has_source
	local ilang = data.ilang

	if raw_args.lang then
		error("The |lang= parameter is not used by this template. Place the language code in parameter 1 instead.")
	end

	local term_index = (ilang and 1 or 2) + (has_source and 1 or 0)
	local params = {
		[term_index] = {list = true, allow_holes = true},
		["sort"] = {},
		["nocap"] = {type = "boolean"}, -- always allow this even if not used, for use with {{surf}}, which adds it
	}

	if not ilang then
		params[1] = {required = true, type = "language", etym_lang = true, default = "und"}
	end

	local source_index
	if has_source then
		source_index = term_index - 1
		params[source_index] = {required = true, type = "language", etym_lang = true, default = "und"}
	end

    local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		-- We want to require an index for all params (or use separate_no_index, which also requires an index for the
		-- param corresponding to the first item).
		{default = true, require_index = true},
		{group = {"link", "ref", "lang", "q", "l"}},
		-- Override these two to have separate_no_index, unless `data.require_index_for_pos` is specified.
		{param = "lit", separate_no_index = true},
		{param = "pos", separate_no_index = not data.require_index_for_pos, require_index = data.require_index_for_pos},
	}
	if data.extra_params then
		data.extra_params(params)
	end

	local items, args = m_param_utils.process_list_arguments {
		params = params,
		param_mods = param_mods,
		raw_args = raw_args,
		termarg = term_index,
		parse_lang_prefix = true,
		track_module = "homophones",
		disallow_custom_separators = true,
		-- For compatibility, we need to not skip completely unspecified items. It is common, for example, to do
		-- {{suffix|lang||foo}} to generate "+ -foo".
		dont_skip_items = true,
		-- Don't pass in `lang` or `sc`, as they will be used as defaults to initialize the items, which we don't want
		-- (particularly for `lang`), as the code in [[Module:affix]] uses the presence of `lang` as an indicator that
		-- a part-specific language was explicitly given.
	}

	local lang = ilang or args[1]
	local source
	if has_source then
		source = args[source_index]
	end

	-- For compatibility with the prior code, we need to convert items without term or properties to nil.
	for i = 1, #items do
		local item = items[i]
		local saw_item_property = item.term
		if not saw_item_property then
			for k, v in pairs(item) do
				if is_property_key(k) then
					saw_item_property = true
					break
				end
			end
		end
		if not saw_item_property then
			items[i] = nil
		end
	end

	return args, items, lang, args.sc.default, source
end


local function augment_affix_data(data, args, lang, sc)
	data.lang = lang
	data.sc = sc
	data.pos = args.pos and args.pos.default
	data.lit = args.lit and args.lit.default
	data.sort = args.sort
	data.type = args.type
	data.nocap = args.nocap
	data.notext = args.notext
	data.nocat = args.nocat
	data.force_cat = args.force_cat
	data.l = args.l.default
	data.ll = args.ll.default
	data.q = args.q.default
	data.qq = args.qq.default
	return data
end


function export.affix(frame)
	local function extra_params(params)
		params.type = {}
		params.notext = {type = "boolean"}
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}

	if args.type and not m_affix.compound_types[args.type] then
		error("Unrecognized compound type: '" .. args.type .. "'")
	end

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) and not args.type then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "prefix-"}, {term = "base"}, {term = "-suffix"} }
		else
			error("You must provide at least one part.")
		end
	end

	return m_affix.show_affix(augment_affix_data({ parts = parts }, args, lang, sc))
end

function export.compound(frame)
	local function extra_params(params)
		params.type = {}
		params.notext = {type = "boolean"}
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}

	if args.type and not m_affix.compound_types[args.type] then
		error("Unrecognized compound type: '" .. args.type .. "'")
	end

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) and not args.type then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		else
			error("You must provide at least one part of a compound.")
		end
	end

	return m_affix.show_compound(augment_affix_data({ parts = parts }, args, lang, sc))
end


function export.compound_like(frame)
	local iparams = {
		["lang"] = {type = "language", etym_lang = true},
		["template"] = {},
		["text"] = {},
		["oftext"] = {},
		["cat"] = {},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)

	local function extra_params(params)
		params.notext = {type = "boolean"}
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
		ilang = iargs.lang,
		-- FIXME, why are we doing this? Formerly we had 'params.pos = nil' whose intention was to disable the overall
		-- pos= while preserving posN=, which is equivalent to the following using the new syntax. But why is this
		-- necessary?
		require_index_for_pos = true,
	}

	local template = iargs.template
	local nocat = args.nocat
	local notext = args.notext
	local text = not notext and iargs.text
	local oftext = not notext and (iargs.oftext or text and "of")
	local cat = not nocat and iargs.cat

	if not next(parts) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		end
	end

	return m_affix.show_compound_like(augment_affix_data({ parts = parts, text = text, oftext = oftext, cat = cat },
		args, lang, sc))
end


function export.surface_analysis(frame)
	local function ine(arg)
		-- Since we're operating before calling [[Module:parameters]], we need to imitate how that module processes
		-- arguments, including trimming since numbered arguments don't have automatic whitespace trimming.
		if not arg then
			return arg
		end
		arg = mw.text.trim(arg)
		if arg == "" then
			arg = nil
		end
		return arg
	end

	local parent_args = frame:getParent().args
	local etymtext
	local arg1 = ine(parent_args[1])
	if not arg1 then
		-- Allow omitted first argument to just display "By surface analysis".
		etymtext = ""
	elseif arg1:find("^%+") then
		-- If the first argument (normally a language code) is prefixed with a +, it's a template name.
		local template_name = arg1:sub(2)
		local new_args = {}
		for i, v in pairs(parent_args) do
			if type(i) == "number" then
				if i > 1 then
					new_args[i - 1] = v
				end
			else
				new_args[i] = v
			end
		end
		new_args.nocap = true
		etymtext = ", " .. frame:expandTemplate { title = template_name, args = new_args }
	end

	if etymtext then
		return (ine(parent_args.nocap) and "b" or "B") .. "y [[Appendix:Glossary#surface analysis|surface analysis]]" ..
			etymtext
	end

	local function extra_params(params)
		params.type = {}
		params.notext = {type = "boolean"}
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = parent_args,
		extra_params = extra_params,
	}

	if args.type and not m_affix.compound_types[args.type] then
		error("Unrecognized compound type: '" .. args.type .. "'")
	end

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		else
			error("You must provide at least one part.")
		end
	end

	return m_affix.show_surface_analysis(augment_affix_data({ parts = parts }, args, lang, sc))
end

local function check_max_items(items, max_allowed)
	if #items > max_allowed then
		local bad_item = items[max_allowed + 1]
		if bad_item.term then
			error(("At most %s terms can be specified but saw a term specified for term #%s")
				:format(max_allowed, max_allowed + 1))
		else
			for k, v in pairs(bad_item) do
				if is_property_key(k) then
					error(("At most %s terms can be specified but saw a value for property '%s' of term #%s")
						:format(max_allowed, k, max_allowed + 1))
				end
			end
		end
		error(("Internal error: Something wrong, %s items generated when there should be at most %s, but item #%s doesn't have a term or any properties")
			:format(#items, max_allowed, max_allowed + 1))
	end
end


function export.circumfix(frame)
	local function extra_params(params)
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}
	check_max_items(parts, 3)

	local prefix = parts[1]
	local base = parts[2]
	local suffix = parts[3]

	-- Just to make sure someone didn't use the template in a silly way
	if not (prefix and base and suffix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			prefix = {term = "circumfix", alt = "prefix"}
			base = {term = "base"}
			suffix = {term = "circumfix", alt = "suffix"}
		else
			error("You must specify a prefix part, a base term and a suffix part.")
		end
	end

	return m_affix.show_circumfix(augment_affix_data({ prefix = prefix, base = base, suffix = suffix }, args, lang, sc))
end


function export.confix(frame)
	local function extra_params(params)
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}
	check_max_items(parts, 3)

	local prefix = parts[1]
	local base = parts[3] and parts[2] or nil
	local suffix = parts[3] or parts[2]

	-- Just to make sure someone didn't use the template in a silly way
	if not (prefix and suffix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			prefix = {term = "prefix"}
			suffix = {term = "suffix"}
		else
			error("You must specify a prefix part, an optional base term and a suffix part.")
		end
	end

	return m_affix.show_confix(augment_affix_data({ prefix = prefix, base = base, suffix = suffix }, args, lang, sc))
end


function export.pseudo_loan(frame)
	local function extra_params(params)
		params.notext = {type = "boolean"}
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
		has_source = true,
		-- FIXME, why are we doing this? Formerly we had 'params.pos = nil' whose intention was to disable the overall
		-- pos= while preserving posN=, which is equivalent to the following using the new syntax. But why is this
		-- necessary?
		require_index_for_pos = true,
	}

	return require(pseudo_loan_module).show_pseudo_loan(
		augment_affix_data({ source = source, parts = parts }, args, lang, sc))
end


function export.infix(frame)
	local function extra_params(params)
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}
	check_max_items(parts, 3)

	local base = parts[1]
	local infix = parts[2]

	-- Just to make sure someone didn't use the template in a silly way
	if not (base and infix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			infix = {term = "infix"}
		else
			error("You must provide a base term and an infix.")
		end
	end

	return m_affix.show_infix(augment_affix_data({ base = base, infix = infix }, args, lang, sc))
end


function export.prefix(frame)
	local function extra_params(params)
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}
	local prefixes = parts
	local base = nil

	local max_prefix = 0
	for k, v in pairs(prefixes) do
		max_prefix = math.max(k, max_prefix)
	end
	if max_prefix >= 2 then
		base = prefixes[max_prefix]
		prefixes[max_prefix] = nil
	end

	-- Just to make sure someone didn't use the template in a silly way
	if not next(prefixes) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			prefixes = { {term = "prefix"} }
		else
			error("You must provide at least one prefix.")
		end
	end

	return m_affix.show_prefix(augment_affix_data({ prefixes = prefixes, base = base }, args, lang, sc))
end


function export.suffix(frame)
	local function extra_params(params)
		params.nocat = {type = "boolean"}
		params.force_cat = {type = "boolean"}
	end

	local args, parts, lang, sc = parse_args {
		raw_args = frame:getParent().args,
		extra_params = extra_params,
	}

	local base = parts[1]
	local suffixes = {}
	for k, v in pairs(parts) do
		suffixes[k - 1] = v
	end

	-- Just to make sure someone didn't use the template in a silly way
	if not next(suffixes) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			suffixes = { {term = "suffix"} }
		else
			error("You must provide at least one suffix.")
		end
	end

	return m_affix.show_suffix(augment_affix_data({ base = base, suffixes = suffixes }, args, lang, sc))
end


function export.derivsee(frame)
	local iargs = frame.args
	local iparams = {
		["derivtype"] = {},
		["mode"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local params = {
		["head"] = {},
		["id"] = {},
		["sc"] = {type = "script"},
		["pos"] = {},
	}
	local derivtype = iargs.derivtype
	if derivtype == "PIE root" then
		params[1] = {}
	else
		params[1] = {required = "true", type = "language", etym_lang = true, default = "und"}
		params[2] = {}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)

	local lang
	local term

	if derivtype == "PIE root" then
		lang = m_languages.getByCode("ine-pro", true)
		term = args[1] or args.head

		if term then
			term = "*" .. term .. "-"
		end
	else
		lang = args[1]
		term = args[2] or args.head
	end

	local id = args.id
	local sc = args.sc
	local pos = require("Module:string utilities").pluralize(args.pos or "term")

	if not term then
		local SUBPAGE = mw.title.getCurrentTitle().subpageText
		if lang:hasType("reconstructed") or mw.title.getCurrentTitle().nsText == "Reconstruction" then
			term = "*" .. SUBPAGE
		elseif lang:hasType("appendix-constructed") then
			term = SUBPAGE
		else
			term = SUBPAGE
		end
	end

	if derivtype == "PIE root" then
		return frame:callParserFunction{
			name = "#categorytree",
			args = {
				"Terms derived from the Proto-Indo-European root " .. term .. (id and " (" .. id .. ")" or ""),
				depth = 0,
				class = "\"derivedterms\"",
				mode = iargs.mode,
				}
			}
	end

	local category = nil
	local langname = lang:getFullName()
	if (derivtype == "compound" and pos == nil) then
		category = langname .. " compounds with " .. term
	elseif derivtype == "compound" and pos == "verbs" then
		category = langname .. " compound " .. pos .. " formed with " .. term
	elseif derivtype == "compound" then
		category = langname .. " compound " .. pos .. " with " .. term
	else
		category = langname .. " " .. pos .. " " .. derivtype .. "ed with " .. term .. (id and " (" .. id .. ")" or "")
	end

	return frame:callParserFunction{
		name = "#categorytree",
		args = {
			category,
			depth = 0,
			class = "\"derivedterms" .. (sc and " " .. sc:getCode() or "") .. "\"",
			namespaces = "-" .. (mw.title.getCurrentTitle().nsText == "Reconstruction" and " Reconstruction" or ""),
			}
		}
end

return export
