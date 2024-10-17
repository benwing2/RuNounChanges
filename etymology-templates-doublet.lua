local export = {}

local require_when_needed = require("Module:require when needed")

local concat = table.concat
local format_categories = require_when_needed("Module:utilities", "format_categories")
local insert = table.insert
local process_params = require_when_needed("Module:parameters", "process")
local serial_comma_join = require_when_needed("Module:table", "serialCommaJoin")

local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulower = string.ulower

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	return (rsubn(term, foo, bar))
end


local function get_parsed_part(template, lang, args, terms, i)
	local term = terms[i]
	local alt = args["alt"][i]
	local id = args["id"][i]
	local sc = args["sc"][i]
	local tr = args["tr"][i]
	local ts = args["ts"][i]
	local gloss = args["t"][i]
	local pos = args["pos"][i]
	local lit = args["lit"][i]
	local g = args["g"][i]

	if not (term or alt or tr or ts) then
		require("Module:debug/track")(template .. "/no term or alt or tr")
		return nil
	else
		return require("Module:links").full_link(
			{ term = term, alt = alt, id = id, lang = lang, sc = sc, tr = tr,
			ts = ts, gloss = gloss, pos = pos, lit = lit,
			genders = g and rsplit(g, ",") or {}
		}, "term", true)
	end
end


local function get_parsed_parts(template, lang, args, terms)
	local parts = {}

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for _, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	for index = 1, maxmaxindex do
		insert(parts, get_parsed_part(template, lang, args, terms, index))
	end
	
	return parts
end

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
		params[1] = {required = true, type = "language", default = "und"}
	end

	local source_index
	if has_source then
		source_index = term_index - 1
		params[source_index] = {required = true, type = "language", default = "und"}
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
end

local function get_args(frame)
	local boolean = {type = "boolean"}
	local list = {list = true, allow_holes = true, require_index = true}
	return process_params(frame:getParent().args, {
		[1] = {
			required = true,
			type = "language",
			default = "und"
		},
		[2] = {list = true, allow_holes = true},
		["t"] = list,
		["gloss"] = {
			list = true,
			allow_holes = true,
			require_index = true,
			alias_of = "t"
		},
		["tr"] = list,
		["ts"] = list,
		["g"] = list,
		["id"] = list,
		["alt"] = list,
		["lit"] = list,
		["pos"] = list,
		["sc"] = {
			type = "script",
			list = true,
			allow_holes = true,
			require_index = true
		},
		["nocap"] = boolean, -- should be processed in the template itself
		["notext"] = boolean,
		["nocat"] = boolean,
		["sort"] = {},
	})
end

-- Implementation of miscellaneous templates such as {{doublet}} that can take
-- multiple terms. Doesn't handle {{blend}} or {{univerbation}}, which display
-- + signs between elements and use compound_like in [[Module:affix/templates]].
function export.misc_variant_multiple_terms(frame)
	local args = get_args(frame)
	local lang = args[1]

	local parts = {}
	if not args["notext"] then
		insert(parts, frame.args["text"])
	end
	if #args[2] > 0 or #args["alt"] > 0 then
		if not args["notext"] then
			insert(parts, " ")
			insert(parts, frame.args["oftext"] or "of")
			insert(parts, " ")
		end
		local formatted_terms = get_parsed_parts(ulower(
			-- Remove link and convert uppercase to lowercase to get an
			-- approximation of the original template name.
			rsub(rsub(frame.args["text"], "^%[%[.*|", ""), "%]%]$", "")),
			lang, args, args[2])
		insert(parts, serial_comma_join(formatted_terms))
	end
	if not args["nocat"] and frame.args["cat"] then
		local categories = {}
		insert(categories, lang:getFullName() .. " " .. frame.args["cat"])
		insert(parts, format_categories(categories, lang, args["sort"]))
	end

	return concat(parts)
end

return export
