local export = {}

local dump = mw.dumpObject
local m_links = require("Module:links")
local form_of_module = "Module:form of"
local labels_module = "Module:labels"
local parse_utilities_module = "Module:parse utilities"
local pron_qualifier_module = "Module:pron qualifier"
local references_module = "Module:references"

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

function export.show_obj(frame)
	local pargs = frame:getParent().args

	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = {list = true},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local lang = args[1]

	local m_parse_utilities = require(parse_utilities_module)

	local qualifier_label_mod = {"q", "qq", "l", "ll"}
	local qualifier_label_mod_with_starred_set = {}
	for _, mod in ipairs(qualifier_label_mod) do
		qualifier_label_mod_with_starred_set[mod] = true
		qualifier_label_mod_with_starred_set[mod .. "*"] = true
	end

	local function parse_object(object, paramno)
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
					local raw_case = run[i]:gsub("^%((.*)%)$", "%1")
					if raw_case:find("[+/&<>()%[%]]") then
						retval.case = parse_object(raw_case, ("%s:%s(...)"):format(retval.form, paramno))
					else
						retval.case = raw_case
					end
				else
					local modtext = run[i]:match("^<(.*)>$")
					if not modtext then
						parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
					end
					local prefix, arg = modtext:match("^([a-z]+%*?):(.*)$")
					if prefix then
						if qualifier_label_mod_with_starred_set[prefix] or prefix == "t" or prefix == "id" or
							prefix == "tr" or prefix == "ts" or prefix == "alt" or prefix == "ref" then
							if not retval.is_term and not qualifier_label_mod_with_starred_set[prefix] and
								prefix ~= "ref" and prefix ~= "t" then
								parse_err("Can't attach prefix '" .. prefix .. "' to non-term")
							end
							local item_dest = prefix == "ref" and "refs" or prefix
							if retval[item_dest] then
								parse_err("Can't set two values for prefix '" .. prefix .. "'")
							end
							if prefix == "l" or prefix == "ll" or prefix == "l*" or prefix == "ll*" then
								arg = require(labels_module).split_labels_on_comma(arg)
							elseif prefix == "ref" then
								arg = require(references_module).parse_references(arg, parse_err)
							end
							retval[item_dest] = arg
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

		local parsed_object = {arguments = {}}
		local orig_segments =
			m_parse_utilities.parse_multi_delimiter_balanced_segment_run(object, {{"[", "]"}, {"(", ")"}, {"<", ">"}})
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

		local split_runs =
			m_parse_utilities.split_alternating_runs(joined_segments, "%s*[+/&]%s*", "preserve splitchar")

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
					local this_alternants = parsed_object.arguments[#parsed_object.arguments].alternants
					-- Join to the previous alternant.
					table.insert(this_alternants, form)
					if not form.is_term and form.form == "etc." then
						for j = 2, #this_alternants do
							this_alternants[j].separator = ", "
						end
					end
				else
					local suppress_with = prev_joiner == "&" 
					-- Create a new argument.
					table.insert(parsed_object.arguments, {alternants = {form}, suppress_with = suppress_with})
				end
			end
			i = i + 2
		end

		-- Now move qualifiers up as necessary.
		local function parse_err(msg)
			error(("%s: %s=%s"):format(msg, paramno, object))
		end
		for _, argument in ipairs(parsed_object.arguments) do
			for i, alternant in ipairs(argument.alternants) do
				if #argument.alternants == 1 then
					-- If there's only one alternant, convert regular qualifiers to starred versions if there's not
					-- already a starred version.
					for _, mod in ipairs(qualifier_label_mod) do
						if alternant[mod] and not alternant[mod .. "*"] then
							alternant[mod .. "*"] = alternant[mod]
							alternant[mod] = nil
						end
					end
				end
				if i < #argument.alternants then
					-- Starred versions cannot be attached to non-final alternants.
					for _, mod in ipairs(qualifier_label_mod) do
						if alternant[mod .. "*"] then
							parse_err(("Starred version '%s' of label or qualifier must be attached to last alternant"):
								format(mod .. "*"))
						end
					end
				else
					-- Starred versions attached to final alternants should be moved up to argument level.
					for _, mod in ipairs(qualifier_label_mod) do
						if alternant[mod .. "*"] then
							argument[mod] = alternant[mod .. "*"]
							alternant[mod .. "*"] = nil
						end
					end
				end
			end
		end

		return parsed_object
	end

	local parsed_objects = {}
	for argno, object in ipairs(args[2]) do
		if object == ";" then
			-- bare semicolon separator, to create a higher-level separation between parameters than
			-- the normal "; or ..." separator.
			if not parsed_objects[1] then
				error("Can't have bare semicolon separator parameter as first parameter")
			end
		else
			-- argno + 1 because object arguments begin at 2=
			local parsed_object = parse_object(object, argno + 1)
			if argno > 1 and args[2][argno - 1] == ";" then
				parsed_object.separator = ";"
			end
			table.insert(parsed_objects, parsed_object)
		end
	end

	local function format_parsed_object(parsed_object, recursive_suppress_with)
		local argument_parts = {}

		local multiple_alternants = false
		for _, argument in ipairs(parsed_object.arguments) do
			if #argument.alternants > 1 then
				multiple_alternants = true
				break
			end
		end

		local used_with_in_prefix = false
		for i, argument in ipairs(parsed_object.arguments) do
			local alternant_parts = {}
			local prefix, separator
			local suppress_with = argument.suppress_with or i == 1 and recursive_suppress_with
			if not suppress_with then
				if not used_with_in_prefix then
					separator = i > 1 and " " or ""
					prefix = "''with'' "
					used_with_in_prefix = true
				elseif multiple_alternants then
					separator = ", "
					prefix = "''along with'' "
				else
					separator = " "
					prefix = "''and'' "
				end
			else
				separator = i > 1 and " " or ""
				prefix = ""
			end

			-- If there are multiple alternants and a non-final alternant has a gloss, assume that each alternant has
			-- its own gloss, or at least that the gloss on the final alternant doesn't apply to all alternants.
			-- Otherwise, we assume the gloss on the final alternant applies to all alternants. This affects the
			-- placement of right labels and qualifiers vis-à-vis the gloss: if there's a single gloss applying to
			-- multiple alternants, we put the right labels and qualifiers before gloss, otherwise after.
			local gloss_with_non_final_alternant = false
			for j, alternant in ipairs(argument.alternants) do
				if j < #argument.alternants and alternant.t then
					gloss_with_non_final_alternant = true
					break
				end
			end

			-- Process each alternant.
			for j, alternant in ipairs(argument.alternants) do
				-- Construct the "case text" for the alternant (what goes in parens). We always assume that a given case
				-- text goes only with its associated alternant, unlike for the gloss (see above).
				local case_text
				if alternant.case then
					if type(alternant.case) == "string" then
						case_text = require(form_of_module).tagged_inflections {
							lang = lang, tags = {alternant.case}, text_classes = text_classes
						}
					else
						case_text = format_parsed_object(alternant.case, "suppress with")
					end
					if alternant.is_postposition then
						case_text = "(" .. case_text .. " +)"
					else
						case_text = "+ " .. case_text
					end
				end

				-- Construct the argument itself (inflection tag or literal word), and add any case text.
				local form
				--local text_classes = "object-usage-form-of-tag"
				local text_classes = "object-usage-tag"
				if alternant.is_term then
					local term = alternant.form
					if term == "" then
						term = nil
					end
					form = m_links.full_link({lang = lang, term = term, alt = alternant.alt, id = alternant.id,
						tr = alternant.tr, ts = alternant.ts, pos = not alternant.is_postposition and case_text or nil},
						"bold")
					if alternant.is_postposition and case_text then
						form = case_text .. " " .. form
					end
				else
					form = require(form_of_module).tagged_inflections {
						lang = lang, tags = {alternant.form}, text_classes = text_classes
					}
					if case_text then
						if alternant.is_postposition then
							form = case_text .. " " .. form
						else
							form = form .. " (" .. case_text .. ")"
						end
					end
				end

				local part = form

				local function add_qualifiers_and_labels_to_alternant(refs)
					if alternant.q or alternant.qq or alternant.l or alternant.ll or refs then
						part = require(pron_qualifier_module).format_qualifiers {
							text = part,
							lang = lang,
							q = alternant.q and {alternant.q} or nil,
							qq = alternant.qq and {alternant.qq} or nil,
							l = alternant.l,
							ll = alternant.ll,
							refs = refs,
						}
					end
				end

				local meaning_text = ""
				if alternant.t then
					meaning_text = " <small>‘" .. alternant.t .. "’</small>"
				end
				if gloss_with_non_final_alternant or #argument.alternants == 1 then
					-- See above. If there is only one alternant, or multiple alternants where each gloss goes with an
					-- individual alternant, right labels and qualifiers go after the gloss, otherwise before. The
					-- reference always goes directly after the form (before the gloss), so if the right labels and
					-- qualifiers go after the gloss, we need to split up their handling.
					if alternant.refs then
						part = require(pron_qualifier_module).format_qualifiers {
							text = part,
							lang = lang,
							refs = alternant.refs,
						}
					end
					part = part .. meaning_text
					add_qualifiers_and_labels_to_alternant()
				else
					add_qualifiers_and_labels_to_alternant(alternant.refs)
 					part = part .. meaning_text
 				end
				if j > 1 and not used_with_in_prefix and not recursive_suppress_with then
					-- If we used e.g. {{+obj|ca|&transitve/:en}} to suppress the initial ''with'', we want it
					-- to appear after the ''or'' so we get ''transitive or with [[en]]'' rather than just
					-- ''transitive or [[en]]''.
					part = "''with'' " .. part
					used_with_in_prefix = true
				end
				if j > 1 then
					table.insert(alternant_parts, alternant.separator or " ''or'' ")
				end
				table.insert(alternant_parts, part)
			end
			local part = prefix .. table.concat(alternant_parts)
			if argument.q or argument.qq or argument.l or argument.ll then
				part = require(pron_qualifier_module).format_qualifiers {
					text = part,
					lang = lang,
					q = argument.q and {argument.q} or nil,
					qq = argument.qq and {argument.qq} or nil,
					l = argument.l,
					ll = argument.ll,
				}
			end
			table.insert(argument_parts, separator .. part)
		end
		return table.concat(argument_parts)
	end

	-- Now generate the text.
	local object_parts = {}
	local function ins(txt)
		table.insert(object_parts, txt)
	end
	ins(require("Module:TemplateStyles")("Module:object usage/style.css"))
	ins("[")
	for i, parsed_object in ipairs(parsed_objects) do
		if i > 1 then
			if parsed_object.separator == ";" then
				ins("; ''in addition,'' ")
			else
				ins("; ''or'' ")
			end
		end
		ins(format_parsed_object(parsed_object, false))
	end
	ins("]")
	return table.concat(object_parts)
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
