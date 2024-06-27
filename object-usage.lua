local export = {}

local m_links = require("Module:links")

local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

-- if not empty
local function ine(val)
	if val == "" then
		return nil
	end
	return val
end

local function parse_form(args, i, default)
	local m_form_data = mw.loadData('Module:form of/data')

	local output = {}
	while args[i] do
		local tag = args[i]
		if m_form_data.shortcuts[tag] then
			tag = m_form_data.shortcuts[tag]
		end
		table.insert(output, tag)
		i = i + 1
	end

	return (#output > 0) and table.concat(output, " ") or default
end

function export.show_bare(frame)
	local pargs = frame:getParent().args
	
	local lang = pargs[1]
	local means = pargs["means"]
	
	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = "und"
		means = "meaning"
	end
	
	lang = lang and require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, 1)
	
	return "[+" .. parse_form(pargs, 2, "object") .. (means and (" = " .. means) or "") .. "]"
end

function export.show_prep(frame)
	local pargs = frame:getParent().args
	
	local lang = pargs[1]
	local means = pargs["means"]
	local term = ine(pargs[2])
	local alt = ine(pargs["alt"])
	local senseid = ine(pargs["senseid"])
	
	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = "und"
		means = "meaning"
		term = "preposition"
	end
	
	lang = lang and require('Module:languages').getByCode(lang) or require('Module:languages').err(lang, 1)

	return "[+ <span>" ..
		require('Module:links').full_link({lang = lang, term = term, alt = alt, id = senseid, tr = "-"}, "term") ..
		" <span>(" .. parse_form(pargs, 3, "object") .. ")</span></span>" .. (means and (" = " .. means) or "") .. "]"
end

function export.show_postp(frame)
	local pargs = frame:getParent().args
	
	local lang = pargs[1]
	local means = pargs["means"] or nil
	local term = ine(pargs[2])
	local alt = ine(pargs["alt"])
	local senseid = ine(pargs["senseid"])
	
	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = "und"
		means = "meaning"
		term = "postposition"
	end
	
	lang = lang and require('Module:languages').getByCode(lang) or require('Module:languages').err(lang, 1)

	return "[+ <span><span>(" .. parse_form(pargs, 3, "object") .. ")</span> " ..
		require('Module:links').full_link({lang = lang, term = term, alt = alt, id = senseid, tr = "-"}, "term") ..
		"</span>" .. (means and (" = " .. means) or "") .. "]"
end


function export.show_obj(frame)
	local pargs = frame:getParent().args

	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = require("Module:languages").getByCode(args[1], 1)

	local iut = require("Module:User:Benwing2/inflection utilities")

	local function parse_one_form(run)
		local function parse_err(msg)
			error(msg .. ": '" .. table.concat(run) .. "'")
		end
		if #run == 1 and run[1] == "" then
			error("Blank form not allowed")
		end
		local retval = {}
		retval.form = run[1]
		retval.form, retval.is_postposition = rsubb(retval.form, "^::", "")
		if retval.is_postposition then
			retval.is_term = true
		else
			retval.form, retval.is_term = rsubb(retval.form, "^:", "")
		end

		for i = 2, #run - 1, 2 do
			if run[i + 1] ~= "" then
				parse_err("Extraneous text '" .. run[i + 1] .. "' after modifier")
			end
			if run[i]:find("^%(") then
				if not retval.is_term then
					parse_err("Can't attach case '" .. run[i] .. "' to non-term")
				end
				retval.case = run[i]:gsub("^%((.*)%)$", "%1")
			else
				local modtext = run[i]:match("^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
				end
				local prefix, arg = modtext:match("^([a-z]+):(.*)$")
				if prefix then
					if prefix == "q" or prefix == "t" or prefix == "id" or prefix == "tr" or prefix == "alt" then
						if not retval.is_term and prefix ~= "q" and prefix ~= "t" then
							parse_err("Can't attach prefix '" .. prefix .. "' to non-term")
						end
						retval[prefix] = arg
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[i])
					end
				else
					retval.t = modtext
				end
			end
		end
		return retval
	end

	local parsed_objects = {}
	for _, object in ipairs(args[2]) do
		local parsed_object = {arguments = {}}
		local orig_segments = iut.parse_multi_delimiter_balanced_segment_run(object, {{"[", "]"}, {"(", ")"}, {"<", ">"}})
		-- rejoin bracketed segments with nearby ones; we only parse them to ensure that we leave alone parens and 
		-- angle brackets inside of square brackets.
		local joined_segments = {}
		local i = 1
		while i <= #orig_segments do
			local segment = orig_segments[i]
			if i % 2 == 0 and segment:find("^%[") then
				joined_segments[#joined_segments] = joined_segments[#joined_segments] .. segment .. orig_segments[i + 1]
				i = i + 2
			else
				table.insert(joined_segments, segment)
				i = i + 1
			end
		end

		local split_runs = iut.split_alternating_runs(joined_segments, "%s*[+/&]%s*", "preserve splitchar")

		-- Now parse the forms.
		i = 1
		while i <= #split_runs do
			if i == 1 and #split_runs[1] == 1 and split_runs[1][1] == "" and #split_runs > 1 and
				rfind(split_runs[2][1], "^%s*&%s*$") then
				-- Blank argument at beginning followed by & to suppress the +. Ignore it.
			else
				local form = parse_one_form(split_runs[i])
				local prev_joiner = i > 1 and rsub(split_runs[i - 1][1], "^%s*(.-)%s*$", "%1")
				if prev_joiner == "/" then
					-- Join to the previous alternant.
					table.insert(parsed_object.arguments[#parsed_object.arguments].alternants, form)
				else
					local suppress_plus = prev_joiner == "&" 
					-- Create a new argument.
					table.insert(parsed_object.arguments, {alternants = {form}, suppress_plus = suppress_plus})
				end
			end
			i = i + 2
		end

		table.insert(parsed_objects, parsed_object)
	end

	-- Now generate the text.
	local object_parts = {}
	for _, parsed_object in ipairs(parsed_objects) do
		local argument_parts = {}

		local multiple_alternants = false
		for _, argument in ipairs(parsed_object.arguments) do
			if #argument.alternants > 1 then
				multiple_alternants = true
				break
			end
		end

		for i, argument in ipairs(parsed_object.arguments) do
			local alternant_parts = {}
			for _, alternant in ipairs(argument.alternants) do
				local form
				--local text_classes = "object-usage-form-of-tag"
				local text_classes = "object-usage-tag"
				if alternant.is_term then
					local term = alternant.form
					if term == "" then
						term = nil
					end
					form = m_links.full_link({lang = lang, term = term, alt = alternant.alt, id = alternant.id, tr = alternant.tr}, "bold")
				else
					form = require("Module:User:Benwing2/form of").tagged_inflections {
						lang = lang, tags = {alternant.form}, text_classes = text_classes
					}
				end

				if alternant.case then
					local case_text = "+ " .. require("Module:User:Benwing2/form of").tagged_inflections {
						lang = lang, tags = {alternant.case}, text_classes = text_classes
					}
					if alternant.is_postposition then
						form = case_text .. " " .. form
					else
						form = form .. " " .. case_text
					end
				end

				local qualifier_text = ""
				if alternant.q then
					qualifier_text = require("Module:qualifier").format_qualifier(alternant.q) .. " "
				end

				local meaning_text = ""
				if alternant.t then
					meaning_text = " <small>‘" .. alternant.t .. "’</small>"
				end
				form = form
				table.insert(alternant_parts, qualifier_text .. form .. meaning_text)
			end
			local prefix
			if not argument.suppress_plus then
				prefix = i > 1 and (multiple_alternants and ", ''along with'' " or " ''and'' ") or "''with'' "
			else
				prefix = i > 1 and " " or ""
			end
			table.insert(argument_parts, prefix .. table.concat(alternant_parts, " ''or'' "))
		end
		table.insert(object_parts, table.concat(argument_parts))
	end

	return require("Module:TemplateStyles")("Module:User:Benwing2/object usage/style.css") .. "[" .. table.concat(object_parts, "; ''or''&ensp;") .. "]"
end


function export.show_aux(frame)
	local pargs = frame:getParent().args

	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true, allow_holes = true},
		["alt"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["id"] = {list = true, allow_holes = true},
		["senseid"] = {list = true, allow_holes = true, alias_of = "id"},
		["means"] = {list = true, allow_holes = true},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = require("Module:languages").getByCode(args[1], 1)

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	if mw.title.getCurrentTitle().nsText == "Template" and mw.title.getCurrentTitle().text == "+aux" then
		return "[auxiliary " .. m_links.full_link({lang = lang, term = "auxiliary"}, "term") .. " = meaning]"
	end

	local parts = {}
	for i = 1, maxmaxindex do
		local term = m_links.full_link({lang = lang, term = args[2][i], alt = args.alt[i], id = args.id[i]}, "term")
		if args.means[i] then
			term = term .. " = " .. args.means[i]
		end
		if args.q[i] then
			term = require("Module:qualifier").format_qualifier(args.q[i]) .. " " .. term
		end
		table.insert(parts, term)
	end

	return "[auxiliary " .. require("Module:table").serialCommaJoin(parts, {conj = "or"}) .. "]"
end


return export
