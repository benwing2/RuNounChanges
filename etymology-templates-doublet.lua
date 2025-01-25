local export = {}

local require_when_needed = require("Module:require when needed")

local concat = table.concat
local format_categories = require_when_needed("Module:utilities", "format_categories")
local insert = table.insert
local process_params = require_when_needed("Module:parameters", "process")
local serial_comma_join = require_when_needed("Module:table", "serialCommaJoin")
local full_link = require_when_needed("Module:links", "full_link")
local parameter_utilities_module = "Module:parameter utilities"

-- Implementation of miscellaneous templates such as {{doublet}} that can take
-- multiple terms. Doesn't handle {{blend}} or {{univerbation}}, which display
-- + signs between elements and use compound_like in [[Module:affix/templates]].
function export.misc_variant_multiple_terms(frame)
	local iparams = {
		["text"] = {},
		["oftext"] = {},
		["cat"] = {},
	}

	local iargs = process_params(frame.args, iparams)

	local boolean = {type = "boolean"}
	local params = {
		[1] = {required = true, type = "language", template_default = "und"},
		[2] = {list = true, allow_holes = true},
		["nocap"] = boolean, -- should be processed in the template itself
		["notext"] = boolean,
		["nocat"] = boolean,
		["sort"] = {},
	}

    local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		-- We want to require an index for all params.
		{default = true, require_index = true},
		{group = {"link", "ref", "lang", "q", "l"}},
	}

	local raw_args = frame:getParent().args
	local items, args = m_param_utils.process_list_arguments {
		params = params,
		param_mods = param_mods,
		raw_args = raw_args,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "etymology-templates-doublet",
		disallow_custom_separators = true,
		-- For compatibility, we need to not skip completely unspecified items. It is common, for example, to do
		-- {{suffix|lang||foo}} to generate "+ -foo".
		dont_skip_items = true,
		lang = 1,
		-- sc = "sc.default", -- FIXME: Do we need this?
	}

	local parts = {}
	if not args.notext then
		insert(parts, iargs.text)
	end
	if items[1] then
		if not args.notext then
			insert(parts, " ")
			insert(parts, iargs.oftext or "of")
			insert(parts, " ")
		end
		local formatted_terms = {}
		for _, item in ipairs(items) do
			insert(formatted_terms, full_link(item, "term", true, "show qualifiers"))
		end
		insert(parts, serial_comma_join(formatted_terms))
	end
	if not args.nocat and iargs.cat then
		local categories = {}
		insert(categories, args[1]:getFullName() .. " " .. iargs.cat)
		insert(parts, format_categories(categories, lang, args.sort))
	end

	return concat(parts)
end

return export
