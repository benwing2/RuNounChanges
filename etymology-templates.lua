local export = {}

local require_when_needed = require("Module:require when needed")

local concat = table.concat
local format_categories = require_when_needed("Module:utilities", "format_categories")
local insert = table.insert
local process_params = require_when_needed("Module:parameters", "process")
local trim = mw.text.trim
local lower = mw.ustring.lower
local dump = mw.dumpObject

local etymology_module = "Module:etymology"
local etymology_specialized_module = "Module:etymology/specialized"
local parameter_utilities_module = "Module:parameter utilities"

-- For testing
local force_cat = false

local allowed_conjs = {"and", "or", ",", "/", "~", ";"}

local function parse_etym_args(parent_args, base_params, has_dest_lang)
	local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		{group = {"link", "q", "l", "ref"}},
	}

	local sourcearg, termarg
	if has_dest_lang then
		sourcearg, termarg = 2, 3
	else
		sourcearg, termarg = 1, 2
	end
	local terms, args = m_param_utils.parse_term_with_inline_modifiers_and_separate_params {
		params = base_params,
		param_mods = param_mods,
		raw_args = parent_args,
		termarg = termarg,
		track_module = "etymology",
		lang = function(args)
			return args[sourcearg][#args[sourcearg]]
		end,
		sc = "sc",
		-- Don't do this, doesn't seem to make sense.
		-- parse_lang_prefix = true,
		make_separate_g_into_list = true,
		splitchar = ",",
		subitem_param_handling = "last",
	}
	-- If term param 3= is empty, there will be no terms in terms.terms. To facilitate further code and for
	-- compatibility,, insert one. It will display as <small>[Term?]</small>.
	if not terms.terms[1] then
		terms.terms[1] = {
			lang = args[sourcearg][#args[sourcearg]],
			sc = args.sc,
		}
	end

	return terms.terms, args
end


function export.parse_2_lang_args(parent_args, has_text, no_family)
	local boolean = {type = "boolean"}
	local params = {
		[1] = {
			required = true,
			type = "language",
			default = "und"
		},
		[2] = {
			required = true,
			sublist = true,
			type = "language",
			family = not no_family,
			default = "und"
		},
		[3] = true,
		[4] = {alias_of = "alt"},
		[5] = {alias_of = "t"},

		["senseid"] = true,
		["nocat"] = boolean,
		["sort"] = true,
		["sourceconj"] = true,
		["conj"] = {set = allowed_conjs, default = ","},
	}
	if has_text then
		params["notext"] = boolean
		params["nocap"] = boolean
	end

	return parse_etym_args(parent_args, params, "has dest lang")
end


-- Implementation of deprecated {{etyl}}. Provided to make histories more legible.
function export.etyl(frame)
	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = {type = "language", default = "en"},
		["sort"] = {},
	}
	-- Empty language means English, but "-" means no language. Yes, confusing...
	local args = frame:getParent().args
	if args[2] and trim(args[2]) == "-" then
		params[2] = nil
		args = process_params({
			[1] = args[1],
			["sort"] = args.sort
		}, params)
	else
		args = process_params(args, params)
	end
	return require(etymology_module).format_source {
		lang = args[2],
		source = args[1],
		sort_key = args.sort,
		force_cat = force_cat,
	}
end


-- Implementation of {{derived}}/{{der}}.
function export.derived(frame)
	local parent_args = frame:getParent().args
	local terms, args = export.parse_2_lang_args(parent_args)
	return require(etymology_module).format_derived {
		lang = args[1],
		sources = args[2],
		terms = terms,
		sort_key = args.sort,
		nocat = args.nocat,
		sourceconj = args.sourceconj,
		conj = args.conj,
		template_name = "derived",
		force_cat = force_cat,
	}
end

-- Implementation of {{borrowed}}/{{bor}}.
function export.borrowed(frame)
	local parent_args = frame:getParent().args
	local terms, args = export.parse_2_lang_args(parent_args)
	return require(etymology_module).format_borrowed {
		lang = args[1],
		sources = args[2],
		terms = terms,
		sort_key = args.sort,
		nocat = args.nocat,
		sourceconj = args.sourceconj,
		conj = args.conj,
		force_cat = force_cat,
	}
end

function export.inherited(frame)
	local parent_args = frame:getParent().args
	local terms, args = export.parse_2_lang_args(parent_args)
	local sources = args[2]
	if sources[2] then
		-- Because this doesn't really make sense.
		error("[[Template:inherited]] doesn't support multiple comma-separated sources")
	end
	return require(etymology_module).format_inherited {
		lang = args[1],
		terms = terms,
		sort_key = args.sort,
		nocat = args.nocat,
		conj = args.conj,
		force_cat = force_cat,
	}
end

function export.cognate(frame)
	local params = {
		[1] = {
			required = true,
			sublist = true,
			type = "language",
			family = true,
			default = "und"
		},
		[2] = true,
		[3] = {alias_of = "alt"},
		[4] = {alias_of = "t"},
		sourceconj = true,
		["conj"] = {set = allowed_conjs, default = ","},
		sort = true,
	}

	local parent_args = frame:getParent().args
	local terms, args = parse_etym_args(parent_args, params, false)

	return require(etymology_module).format_cognate {
		sources = args[1],
		terms = terms,
		sort_key = args.sort,
		sourceconj = args.sourceconj,
		conj = args.conj,
		force_cat = force_cat,
	}
end

function export.noncognate(frame)
	return export.cognate(frame)
end

-- Supports various specialized types of borrowings, according to `frame.args.bortype`:
--   "learned" = {{lbor}}/{{learned borrowing}}
--   "semi-learned" = {{slbor}}/{{semi-learned borrowing}}
--   "orthographic" = {{obor}}/{{orthographic borrowing}}
--   "unadapted" = {{ubor}}/{{unadapted borrowing}}
--   "calque" = {{cal}}/{{calque}}
--   "partial-calque" = {{pcal}}/{{partial calque}}
--   "semantic-loan" = {{sl}}/{{semantic loan}}
--   "transliteration" = {{translit}}/{{transliteration}}
--   "phono-semantic-matching" = {{psm}}/{{phono-semantic matching}}
function export.specialized_borrowing(frame)
	local parent_args = frame:getParent().args
	local terms, args = export.parse_2_lang_args(parent_args, "has text")
	local m_etymology_specialized = require(etymology_specialized_module)
	return m_etymology_specialized.specialized_borrowing {
		bortype = frame.args.bortype,
		lang = args[1],
		sources = args[2],
		terms = terms,
		sort_key = args.sort,
		nocap = args.nocap,
		notext = args.notext,
		nocat = args.nocat,
		sourceconj = args.sourceconj,
		conj = args.conj,
		senseid = args.senseid,
		force_cat = force_cat,
	}
end


-- Implementation of miscellaneous templates such as {{abbrev}}, {{back-formation}}, {{clipping}}, {{ellipsis}},
-- {{rebracketing}} and {{reduplication}} that have a single associated term.
function export.misc_variant(frame)
	local iparams = {
		["ignore-params"] = true,
		text = {required = true},
		oftext = true,
		cat = {list = true}, -- allow and compress holes
		conj = true,
	}

	local iargs = process_params(frame.args, iparams)

	local boolean = {type = "boolean"}

	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = true,
		[3] = {alias_of = "alt"},
		[4] = {alias_of = "t"},

		nocap = boolean, -- should be processed in the template itself
		notext = boolean,
		nocat = boolean,
		conj = {set = allowed_conjs},
		sort = true,
	}

	-- |ignore-params= parameter to module invocation specifies
	-- additional parameter names to allow  in template invocation, separated by
	-- commas. They must consist of ASCII letters or numbers or hyphens.
	local ignore_params = iargs["ignore-params"]
	if ignore_params then
		ignore_params = trim(ignore_params)
		if not ignore_params:match("^[%w%-,]+$") then
			error("Invalid characters in |ignore-params=: " .. ignore_params:gsub("[%w%-,]+", ""))
		end
		for param in ignore_params:gmatch("[%w%-]+") do
			if params[param] then
				error("Duplicate param |" .. param
					.. " in |ignore-params=: already specified in params")
			end
			params[param] = true
		end
	end

	local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		{group = {"link", "q", "l", "ref"}},
	}

	local parent_args = frame:getParent().args

	local terms, args = m_param_utils.parse_term_with_inline_modifiers_and_separate_params {
		params = params,
		param_mods = param_mods,
		raw_args = parent_args,
		termarg = 2,
		track_module = "etymology",
		lang = 1,
		sc = "sc",
		-- Don't do this, doesn't seem to make sense.
		-- parse_lang_prefix = true,
		make_separate_g_into_list = true,
		splitchar = ",",
		subitem_param_handling = "last",
	}

	return require(etymology_module).format_misc_variant {
		lang = args[1],
		notext = args.notext,
		text = iargs.text,
		terms = terms.terms,
		sort_key = args.sort,
		conj = args.conj or iargs.conj or "and",
		nocat = args.nocat,
		cat = iargs.cat,
		force_cat = force_cat,
	}
end


-- Implementation of miscellaneous templates such as {{doublet}} that can take multiple terms. Doesn't handle {{blend}}
-- or {{univerbation}}, which display + signs between elements and use compound_like in [[Module:affix/templates]].
function export.misc_variant_multiple_terms(frame)
	local iparams = {
		text = {required = true},
		oftext = true,
		cat = {list = true}, -- allow and compress holes
		conj = true,
	}

	local iargs = process_params(frame.args, iparams)

	local boolean = {type = "boolean"}

	local params = {
		[1] = {required = true, type = "language", template_default = "und"},
		[2] = {list = true, allow_holes = true},
		nocap = boolean, -- should be processed in the template itself
		notext = boolean,
		nocat = boolean,
		conj = {set = allowed_conjs},
		sort = true,
	}

    local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		-- We want to require an index for all params.
		{default = true, require_index = true},
		{group = {"link", "q", "l", "ref"}},
	}

	local parent_args = frame:getParent().args

	local terms, args = m_param_utils.parse_list_with_inline_modifiers_and_separate_params {
		params = params,
		param_mods = param_mods,
		raw_args = parent_args,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "etymology-templates-doublet",
		disallow_custom_separators = true,
		-- For compatibility, we need to not skip completely unspecified items. It is common, for example, to do
		-- {{suffix|lang||foo}} to generate "+ -foo".
		dont_skip_items = true,
		lang = 1,
		sc = "sc.default",
	}

	return require(etymology_module).format_misc_variant {
		lang = args[1],
		notext = args.notext,
		text = iargs.text,
		terms = terms,
		sort_key = args.sort,
		conj = args.conj or iargs.conj or "and",
		nocat = args.nocat,
		cat = iargs.cat,
		force_cat = force_cat,
	}
end

-- Implementation of miscellaneous templates such as {{unknown}} that have no associated terms.
do
	local function get_args(frame)
		local boolean = {type = "boolean"}
		local params = {
			[1] = {required = true, type = "language", default = "und"},

			["title"] = true,
			["nocap"] = boolean, -- should be processed in the template itself
			["notext"] = boolean,
			["nocat"] = boolean,
			["sort"] = true,
		}
		if frame.args.title2_alias then
			params[2] = {alias_of = "title"}
		end
		return process_params(frame:getParent().args, params)
	end

	function export.misc_variant_no_term(frame)
		local args = get_args(frame)

		return require(etymology_module).format_misc_variant_no_term {
			lang = args[1],
			notext = args.notext,
			title = args.title or frame.args.text,
			nocat = args.nocat,
			cat = frame.args.cat,
			sort_key = args.sort,
			force_cat = force_cat,
		}
	end

	-- This function works similarly to misc_variant_no_term(), but with some automatic linking to the glossary in
	-- `title`.
	function export.onomatopoeia(frame)
		local args = get_args(frame)

		local title = args.title
		if title and (lower(title) == "imitative" or lower(title) == "imitation") then
			title = "[[Appendix:Glossary#imitative|" .. title .. "]]"
		end

		return require(etymology_module).format_misc_variant_no_term {
			lang = args[1],
			notext = args.notext,
			title = title or frame.args.text,
			nocat = args.nocat,
			cat = frame.args.cat,
			sort_key = args.sort,
			force_cat = force_cat,
		}
	end
end

return export
