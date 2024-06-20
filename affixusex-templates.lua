local export = {}

local require = require

local affixusex_module = "Module:affixusex"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"

local concat = table.concat
local find = string.find
local gsub = string.gsub
local insert = table.insert
local match = string.match
local sort = table.sort
local sub = string.sub

function export.affixusex_t(frame)
	local parent_args = frame:getParent().args

	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		[2] = {list = true, allow_holes = true},

		["altaff"] = {},
		["nointerp"] = {type = "boolean"},
		["pagename"] = {},
	}

	local aftype = frame.args["type"]
	if aftype == "" or not aftype then
		aftype = "affix"
	end

	if aftype == "prefix" then
		params.altpref = {alias_of = "altaff"}
	elseif aftype == "suffix" then
		params.altsuf = {alias_of = "altaff"}
	end

    local m_param_utils = require(parameter_utilities_module)
	local param_mods = m_param_utils.construct_param_mods {
		-- We want to require an index for all params. Some of the params generated below have separate_no_index, which
		-- overrides require_index (and also requires an index for the param corresponding to the first item).
		{default = true, require_index = true},
		{set = {"link", "ref", "lang", "q", "l"}},
		{param = "arrow", type = "boolean"},
		{param = {"joiner", "fulljoiner"}},
	}
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require(parameters_module).process(parent_args, params)

	local lang = args[1]
	local sc = args.sc.default

	-- Remember and remove an exclamation point from the beginning of a term. We need to do this *before* parsing
	-- inline modifiers because the exclamation point goes before a language prefix, which is split off as part of
	-- parsing inline modifiers.
	local has_exclamation_point = {}
	for i, term in ipairs(args[2]) do
		if sub(term, 1, 1) == "!" then
			has_exclamation_point[i] = true
			args[2][i] = gsub(term, "^!", "")
		end
	end

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "affixusex",
	}

	local data = {
		items = items,
		lang = lang,
		sc = sc,
	}
	require(pron_qualifier_module).parse_qualifiers {
		store_obj = data,
		l = args.l.default,
		ll = args.ll.default,
		q = args.q.default,
		qq = args.qq.default,
	}

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename

	-- Determine whether the terms in the numbered params contain a prefix or suffix. If not, we may insert one before
	-- the last term (for suffixes) or the first term (for prefixes).
	local affix_in_items = false
	for i, item in ipairs(items) do
		if item.term then
			-- Careful here, a prefix beginning with ! should be treated as a normal term.
			if has_exclamation_point[item.orig_index] or ((item.lang or lang):makeEntryName(item.term)) == pagename then
				affix_in_items = true
				if not item.alt then
					item.alt = item.term
					item.term = nil
				end
			end
		end
	end

	-- Determine affix to check for prefixness/suffixness.
	local insertable_aff = args.altaff or pagename

	-- Determine affix to interpolate if needed.
	local affix = args.altaff
	if not affix then
		if lang:hasType("reconstructed") then
			affix = "*" .. pagename
		else
			affix = pagename
		end
	end

	-- Insert suffix derived from page title or altaff=/altsuf= before the last component if
	-- (a) nointerp= isn't present, and
	-- (b) no suffix is present among the parts (where "suffix" means a part that matches the subpage name after
	--     diacritics have been removed, or a part prefixed by !), and either
	--    (i) {{suffixusex}}/{{sufex}} was used;
	--    (ii) {{affixusex}}/{{afex}} was used and altaff= is given, and its value looks like a suffix (begins with -,
	--         doesn't end in -; an infix is not a suffix)
	--    (iii) {{affixusex}}/{{afex}} was used and altaff= is not given and the subpage title looks like a suffix
	--          (same conditions as for altaff=)
	-- Insert prefix derived from page title or altaff=/altpref= before the first component using similar logic as
	-- preceding.
	if not args.nointerp and not affix_in_items then
		if aftype == "prefix" or (
			aftype == "affix" and
			sub(insertable_aff, -1) == "-" and
			sub(insertable_aff, 1, 1) ~= "-"
		) then
			insert(items, 1, {alt = affix})
		elseif aftype == "suffix" or (
			aftype == "affix" and
			sub(insertable_aff, 1, 1) == "-" and
			sub(insertable_aff, -1) ~= "-"
		) then
			insert(items, #items, {alt = affix})
		end
	end

	return require(affixusex_module).format_affixusex(data)
end

return export
