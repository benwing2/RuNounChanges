local export = {}

local m_IPA = require("Module:IPA")
local m_str_utils = require("Module:string utilities")
local parse_utilities_module = "Module:parse utilities"
local pron_qualifier_module = "Module:pron qualifier"
local references_module = "Module:references"

local rsplit = m_str_utils.split

local function track(page)
	require("Module:debug").track("IPA/" .. page)
	return true
end

local function split_on_comma(term)
	if not term then
		return nil
	end
	if term:find(",%s") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

-- Used for [[Template:IPA]].
function export.IPA(frame)
	local parent_args = frame:getParent().args
	if parent_args.qual then
		-- FIXME: Convert such uses to q1= (or at least qual1=).
		track("bare-qual")
	end
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1
	local params = {
		[compat and "lang" or 1] = {required = true, type = "language", default = "en"},
		[1 + offset] = {list = true, allow_holes = true},
		["ref"] = {list = true, allow_holes = true},
		-- Came before 'ref' but too obscure
		["n"] = {list = true, allow_holes = true, alias_of = "ref"},
		["a"] = {list = true, allow_holes = true, separate_no_index = true},
		["aa"] = {list = true, allow_holes = true, separate_no_index = true},
		["q"] = {list = true, allow_holes = true, separate_no_index = true},
		["qq"] = {list = true, allow_holes = true, separate_no_index = true},
		["qual"] = {list = true, allow_holes = true},
		["nocount"] = {type = "boolean"},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(parent_args, params)
	local lang = args[compat and "lang" or 1]

	local items = {}
	
	for i = 1, math.max(args[1 + offset].maxindex, args["ref"].maxindex, args["qual"].maxindex) do
		local pron = args[1 + offset][i]
		local refs = args["ref"][i]
		if refs then
			refs = require(references_module).parse_references(refs)
		end
		local qual = args["qual"][i]
		if qual then
			-- FIXME: Convert such uses to qN=.
			track("qual")
		end

		if not pron then
			-- FIXME: Eliminate such uses, then make them an error through disallow_holes = true.
			track("empty-pron")
			if refs or qual then
				local param = i == 1 and "" or "" .. i
				error("Specified qual" .. param .. "= or ref" .. param .. "= without corresponding pronunciation")
			end
		else
			require("Module:IPA/tracking").run_tracking(pron, lang)

			table.insert(items, {
				pron = pron,
				refs = refs,
				q = args.q[i] and {args.q[i]} or nil,
				qq = args.qq[i] and {args.qq[i]} or nil,
				a = split_on_comma(args.a[i]),
				aa = split_on_comma(args.aa[i]),
				-- FIXME, remove this
				qualifiers = qual and {qual} or nil,
			})
		end
	end

	local retval = m_IPA.format_IPA_full(lang, items, nil, nil, args.sort, args.nocount)
	if args.q.default or args.qq.default or args.a.default or args.aa.default then
		return require(pron_qualifier_module).format_qualifiers {
			lang = lang,
			text = retval,
			q = args.q.default and {args.q.default} or nil,
			qq = args.qq.default and {args.qq.default} or nil,
			a = split_on_comma(args.a.default),
			aa = split_on_comma(args.aa.default),
		}
	else
		return retval
	end
end

-- Used for [[Template:IPAchar]].
function export.IPAchar(frame)
	local params = {
		[1] = {list = true, allow_holes = true},
		["ref"] = {list = true, allow_holes = true},
		-- Came before 'ref' but too obscure
		["n"] = {list = true, allow_holes = true, alias_of = "ref"},
		["qual"] = {list = true, allow_holes = true},
		-- FIXME, remove this.
		["lang"] = {}, -- This parameter is not used and does nothing, but is allowed for futureproofing.
	}

	local args = require("Module:parameters").process(frame.getParent and frame:getParent().args or frame, params)
	
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/IPAchar/lang]]
	if args.lang then
		require("Module:debug").track("IPAchar/lang")
	end

	local items = {}
	
	for i = 1, math.max(args[1].maxindex, args["ref"].maxindex, args["qual"].maxindex) do
		local pron = args[1][i]
		local refs = args["ref"][i]
		if refs then
			refs = require("Module:references").parse_references(refs)
		end
		local qual = args["qual"][i]

		if pron or refs or qual then
			table.insert(items, {pron = pron, refs = refs, qualifiers = {qual}})
		end
	end

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
		-- Came before 'ref' but too obscure
		["n"] = {list = true, allow_holes = true, alias_of = "ref"},
		["qual"] = { list = true, allow_holes = true },
	}
	
	local args = require("Module:parameters").process(parent_args, params)
	
	local m_XSAMPA = require("Module:IPA/X-SAMPA")
	
	local pronunciations, refs, qualifiers, lang = args[1 + offset], args["ref"], args["qual"], args[compat and "lang" or 1]
	
	local output = {}
	table.insert(output, "{{IPA")
	
	table.insert(output, "|" .. lang)

	for i = 1, math.max(pronunciations.maxindex, refs.maxindex, qualifiers.maxindex) do
		if pronunciations[i] then
			table.insert(output, "|" .. m_XSAMPA.XSAMPA_to_IPA(pronunciations[i]))
		end
		if refs[i] then
			table.insert(output, "|ref" .. i .. "=" .. refs[i])
		end
		if qualifiers[i] then
			table.insert(output, "|qual" .. i .. "=" .. qualifiers[i])
		end
	end
	
	table.insert(output, "}}")

	return table.concat(output)
end

-- Used by [[Template:X2IPAchar]]
function export.X2IPAchar(frame)
	local params = {
		[1] = { list = true, allow_holes = true },
		["ref"] = {list = true, allow_holes = true},
		-- Came before 'ref' but too obscure
		["n"] = {list = true, allow_holes = true, alias_of = "ref"},
		["qual"] = { list = true, allow_holes = true },
		-- FIXME, remove this.
		["lang"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	-- [[Special:WhatLinksHere/Wiktionary:Tracking/X2IPAchar/lang]]
	if args.lang then
		require("Module:debug").track("X2IPAchar/lang")
	end

	local m_XSAMPA = require("Module:IPA/X-SAMPA")
	
	local pronunciations, refs, qualifiers, lang = args[1], args["ref"], args["qual"], args["lang"]
	
	local output = {}
	table.insert(output, "{{IPAchar")
	
	for i = 1, math.max(pronunciations.maxindex, refs.maxindex, qualifiers.maxindex) do
		if pronunciations[i] then
			table.insert(output, "|" .. m_XSAMPA.XSAMPA_to_IPA(pronunciations[i]))
		end
		if refs[i] then
			table.insert(output, "|ref" .. i .. "=" .. refs[i])
		end
		if qualifiers[i] then
			table.insert(output, "|qual" .. i .. "=" .. qualifiers[i])
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

return export
