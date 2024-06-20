local export = {}

local m_IPA = require("Module:IPA")
local parameter_utilities_module = "Module:parameter utilities"
local references_module = "Module:references"

local function track(template, page)
	require("Module:debug/track")(template .. "/" .. page)
	return true
end

-- Used for [[Template:IPA]].
function export.IPA(frame)
	local parent_args = frame:getParent().args
	-- Track uses of n so they can be converted to ref.
	-- Track uses of qual so they can be converted to q.
	for k, v in pairs(parent_args) do
		if type(k) == "string" and k:find("^qual[0-9]*$") then
			track("IPA", "q")
		end
	end
	local include_langname = frame.args.include_langname
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[1 + offset] = {list = true, disallow_holes = true},
		-- Deprecated; don't use in new code.
		["qual"] = {list = true, allow_holes = true, separate_no_index = true, alias_of = "q"},
		["nocount"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
	}

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{set = {"ref", "a", "q"}},
		{set = "link", include = {"t", "gloss", "pos"}},
	}

	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)

	local lang = args[compat and "lang" or 1]

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1 + offset,
		term_dest = "pron",
		track_module = "IPA",
	}
	for _, item in ipairs(items) do
		require("Module:IPA/tracking").run_tracking(item.pron, lang)
	end

	local data = {
		lang = lang,
		items = items,
		no_count = args.nocount,
		nocat = args.nocat,
		sort_key = args.sort,
		include_langname = include_langname,
		q = args.q.default,
		qq = args.qq.default,
		a = args.a.default,
		aa = args.aa.default,
	}

	return m_IPA.format_IPA_full(data)
end

-- Used for [[Template:IPAchar]].
function export.IPAchar(frame)
	local parent_args = frame.getParent and frame:getParent().args or frame
	-- Track uses of n so they can be converted to ref.
	-- Track uses of qual so they can be converted to q.
	for k, v in pairs(parent_args) do
		if type(k) == "string" and k:find("^n[0-9]*$") then
			track("IPAchar", "n")
		end
		if type(k) == "string" and k:find("^qual[0-9]*$") then
			track("IPAchar", "q")
		end
	end

	local params = {
		[1] = {list = true, disallow_holes = true},
		-- FIXME, remove this.
		["lang"] = {}, -- This parameter is not used and does nothing, but is allowed for futureproofing.
	}

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		-- It doesn't really make sense to have separate overall a=/aa=/q=/qq= for {{IPAchar}}, which doesn't format a
		-- whole line but just individual pronunciations. Instead they are associated with the first item.
		{set = {"ref", "a", "q"}, separate_no_index = false},
		-- Deprecated; don't use in new code.
		{param = "n", alias_of = "ref"},
		-- Deprecated; don't use in new code.
		{param = "qual", alias_of = "q"},
	}

	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)
	
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/IPAchar/lang]]
	if args.lang then
		track("IPAchar", "lang")
	end

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1,
		term_dest = "pron",
		track_module = "IPAchar",
	}

	-- Format
	return m_IPA.format_IPA_multiple(nil, items)
end

function export.XSAMPA(frame)
	local params = {
		[1] = { required = true },
	}
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	return m_IPA.XSAMPA_to_IPA(args[1] or "[Eg'zA:mp5=]")
end

-- Used by [[Template:X2IPA]]
function export.X2IPAtemplate(frame)
	local parent_args = frame.getParent and frame:getParent().args or frame
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, default = "und"},
		[1 + offset] = {list = true, allow_holes = true},
		["ref"] = {list = true, allow_holes = true},
		["a"] = {list = true, allow_holes = true, separate_no_index = true},
		["aa"] = {list = true, allow_holes = true, separate_no_index = true},
		["q"] = {list = true, allow_holes = true, separate_no_index = true},
		["qq"] = {list = true, allow_holes = true, separate_no_index = true},
		["qual"] = {list = true, allow_holes = true},
		["nocount"] = {type = "boolean"},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(parent_args, params)
	
	local m_XSAMPA = require("Module:IPA/X-SAMPA")
	
	local pronunciations, refs, a, aa, q, qq, qual, lang =
		args[1 + offset], args.ref, args.a, args.aa, args.q, args.qq, args.qual, args[compat and "lang" or 1]
	
	local output = {}
	table.insert(output, "{{IPA")
	
	table.insert(output, "|" .. lang)

	if a.default then
		table.insert(output, "|a=" .. a.default)
	end
	if q.default then
		table.insert(output, "|q=" .. q.default)
	end
	for i = 1, math.max(pronunciations.maxindex, refs.maxindex, a.maxindex, aa.maxindex, q.maxindex, qq.maxindex,
		qual.maxindex) do
		if pronunciations[i] then
			table.insert(output, "|" .. m_XSAMPA.XSAMPA_to_IPA(pronunciations[i]))
		end
		if a[i] then
			table.insert(output, "|a" .. i .. "=" .. a[i])
		end
		if aa[i] then
			table.insert(output, "|aa" .. i .. "=" .. aa[i])
		end
		if q[i] then
			table.insert(output, "|q" .. i .. "=" .. q[i])
		end
		if qq[i] then
			table.insert(output, "|qq" .. i .. "=" .. qq[i])
		end
		if refs[i] then
			table.insert(output, "|ref" .. i .. "=" .. refs[i])
		end
		if qual[i] then
			table.insert(output, "|qual" .. i .. "=" .. qual[i])
		end
	end
	if aa.default then
		table.insert(output, "|aa=" .. aa.default)
	end
	if qq.default then
		table.insert(output, "|qq=" .. qq.default)
	end
	if args.nocount then
		table.insert(output, "|nocount=1")
	end
	if args.sort then
		table.insert(output, "|sort=" .. args.sort)
	end
	
	table.insert(output, "}}")

	return table.concat(output)
end

-- Used by [[Template:X2IPAchar]]
function export.X2IPAchar(frame)
	local params = {
		[1] = { list = true, allow_holes = true },
		["ref"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true, require_index = true},
		["qq"] = {list = true, allow_holes = true, require_index = true},
		["qual"] = { list = true, allow_holes = true },
		-- FIXME, remove this.
		["lang"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/X2IPAchar/lang]]
	if args.lang then
		track("X2IPAchar", "lang")
	end

	local m_XSAMPA = require("Module:IPA/X-SAMPA")
	
	local pronunciations, refs, q, qq, qual, lang = args[1], args.ref, args.q, args.qq, args.qual, args.lang
	
	local output = {}
	table.insert(output, "{{IPAchar")
	
	for i = 1, math.max(pronunciations.maxindex, refs.maxindex, q.maxindex, qq.maxindex, qual.maxindex) do
		if pronunciations[i] then
			table.insert(output, "|" .. m_XSAMPA.XSAMPA_to_IPA(pronunciations[i]))
		end
		if q[i] then
			table.insert(output, "|q" .. i .. "=" .. q[i])
		end
		if qq[i] then
			table.insert(output, "|qq" .. i .. "=" .. qq[i])
		end
		if qual[i] then
			table.insert(output, "|qual" .. i .. "=" .. qual[i])
		end
		if refs[i] then
			table.insert(output, "|ref" .. i .. "=" .. refs[i])
		end
	end

	if lang then
		table.insert(output, "|lang=" .. lang)
	end
	
	table.insert(output, "}}")
	
	return table.concat(output)
end

-- Used by [[Template:x2rhymes]]
function export.X2rhymes(frame)
	local parent_args = frame.getParent and frame:getParent().args or frame
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, default = "und"},
		[1 + offset] = {required = true, list = true, allow_holes = true},
	}
	
	local args = require("Module:parameters").process(parent_args, params)
	
	local m_XSAMPA = require("Module:IPA/X-SAMPA")
	
	pronunciations, lang = args[1 + offset], args[compat and "lang" or 1]
	
	local output =  {}
	table.insert(output, "{{rhymes")
	
	table.insert(output, "|" .. lang)

	for i = 1, pronunciations.maxindex do
		if pronunciations[i] then
			table.insert(output, "|" .. m_XSAMPA.XSAMPA_to_IPA(pronunciations[i]))
		end
	end
	
	table.insert(output, "}}")
	
	return table.concat(output)
end

-- Used for [[Template:enPR]].
function export.enPR(frame)
	local parent_args = frame:getParent().args

	local params = {
		[1] = {list = true, disallow_holes = true},
	}

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{set = {"q", "a", "ref"}},
	}

	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1,
		term_dest = "pron",
		track_module = "enPR",
	}

	local data = {
		items = items,
		q = args.q.default,
		qq = args.qq.default,
		a = args.a.default,
		aa = args.aa.default,
	}

	return m_IPA.format_enPR_full(data)
end

return export
