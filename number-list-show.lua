local export = {}

local m_number_list = require("Module:number list")

local function link_forms(forms, m_data, lang)
	if type(forms) ~= "table" then
		forms = {forms}
	end
	local seen_forms, forms_by_tag, seen_tags = m_number_list.group_numeral_forms_by_tag(forms)
	local formatted_forms = {}
	for _, tag in ipairs(seen_tags) do
		local formatted_tag_forms = {}

		for _, formobj in ipairs(forms_by_tag[tag]) do
			table.insert(formatted_tag_forms, m_number_list.format_formobj(formobj, m_data, lang))
		end
		formatted_tag_forms = table.concat(formatted_tag_forms, ", ")
		if tag == "" then
			if #seen_tags == 1 then
				table.insert(formatted_forms, formatted_tag_forms)
			else
				table.insert(formatted_forms, ("(default): %s"):format(formatted_tag_forms))
			end
		else
			table.insert(formatted_forms, ("%s: %s"):format(tag, formatted_tag_forms))
		end
	end

	return table.concat(formatted_forms, "<br />")
end

local function num_to_ordinal(numstr)
	if numstr:find("1$") then
		return numstr .. "st"
	elseif numstr:find("2$") then
		return numstr .. "nd"
	elseif numstr:find("3$") then
		return numstr .. "rd"
	else
		return numstr .. "th"
	end
end

local function print_full_table(lang, m_data)
	local full_link = require("Module:links").full_link
	local tag_text = require("Module:script utilities").tag_text
	local function tag(form)
		return tag_text(form, lang)
	end

	local form_types = m_number_list.get_number_types(m_data)
	local numeral_index = 1
	table.insert(form_types, numeral_index,
		{key = "numeral", display = "Numeral"})
	table.insert(form_types, {key = "wplink", display = "Wikipedia link"})
	local wplink_index = #form_types

	local number_type_indices = {}
	for number, data in pairs(m_data.numbers) do
		for i, form_type in pairs(form_types) do
			if data[form_type.key] then
				number_type_indices[i] = true
			end
		end
	end

	local numeral_config = m_data.numeral_config
	if numeral_config then
		number_type_indices[numeral_index] = true
	end

	local has_wplink_column = number_type_indices[wplink_index]

	number_type_indices = require("Module:table").keysToList(number_type_indices)

	local Array = require("Module:array")
	local output = Array()

	local function header(content)
		output:insert(("! %s"):format(content))
	end

	local function cell(content)
		output:insert(("| %s"):format(content))
	end

	local function row(content)
		output:insert("|-\n")
		if content then
			cell(content)
		end
	end

	output:insert('{| class="wikitable"')

	-- Add headers.
	header("Number")
	for _, index in ipairs(number_type_indices) do
		header(m_number_list.display_number_type(form_types[index]))
	end

	local errors = Array()

	for number, data in require("Module:table").sortedPairs(m_data.numbers, m_number_list.numbers_less_than) do
		local function check_string(val)
			if type(val) ~= "string" then
				error(("For number %s, Expected string but saw '%s"):format(number, mw.dumpObject(val)))
			end
		end
		local number_string = m_number_list.format_fixed(number)

		row(m_number_list.format_number_for_display(number_string))

		local numeral
		if numeral_config then
			numeral = m_number_list.generate_non_arabic_numeral(numeral_config, number_string)
		elseif data.numeral then
			numeral = data.numeral
		end
		if numeral then
			check_string(numeral)
			numeral = tag(numeral)
			cell(numeral or "")
		end

		for _, i in ipairs(number_type_indices) do
			if i ~= numeral_index and i ~= wplink_index then
				local form = data[form_types[i].key]
				cell(form and link_forms(form, data, lang) or "")
			end
		end

		if data.wplink then
			check_string(data.wplink)
			cell(("[[w:%s:%s|%s]]"):format(lang:getCode(), data.wplink, data.wplink))
		elseif has_wplink_column then
			cell("")
		end

		-- Check for numerical indices, which are syntax errors.
		for i, word in ipairs(data) do
			if type(word) == "string" then
				errors:insert({ number = number_string, word = word })
			end
		end
	end

	output:insert('|}')

	if #errors > 0 then
		output:insert(
			1,
			'\n<span class="error">The following numbers were not inserted '
			.. "correctly and need to be placed inside table syntax: "
			.. errors
				:map(
					function(data)
						return data.number .. ": " .. data.word
					end)
				:concat ", "
			.. "[[Category:Errors in number data modules|"
			.. lang:getCode() .. "]]</span>")
	end

	return output:concat("\n")
end

function export.number_table(frame)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {required = true, default = "cardinal"},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local langcode = args[1]
	local lang = require("Module:languages").getByCode(langcode, 1)
	local data_module_name = m_number_list.get_data_module_name(langcode, "must exist")
	local m_data = require(data_module_name)
	if args[2] == "full" then
		return print_table(lang, m_data)
	end

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	-- Find minimum and maximum attested number and row.
	local min_num
	local max_num = 0
	local min_row
	local max_row = 0
	for i = 0, 9 do
		for j = 0, 9 do
			local num = i * 10 + j
			local num_data = m_number_list.lookup_data(m_data, tostring(num))
			local forms = num_data and num_data[args[2]]
			if forms and #forms > 0 then
				min_num = min_num or num
				max_num = num
				min_row = min_row or i
				max_row = i
			end
		end
	end
	min_num = min_num or 0
	min_row = min_row or 0

	ins([=[<div class="NavFrame" style="">
<div class="NavHead">]=])
	ins(lang:getCanonicalName())
	ins(" ")
	local min_ord = num_to_ordinal(tostring(min_num))
	local max_ord = num_to_ordinal(tostring(max_num))
	if args[2] == "ordinal" then
		ins(("ordinal numbers from %s to %s"):format(min_ord, max_ord))
	elseif args[2] == "ordinal_abbr" then
		ins(("ordinal abbreviations from %s to %s"):format(min_ord, max_ord))
	else
		ins(args[2])
		ins((" numbers from %s to %s"):format(min_num, max_num))
	end
	ins([=[</div>
<div class="NavContent" style="">
{| class="wikitable" style="width:100%;height:100%;font-size:8pt"
!
!—0
!—1
!—2
!—3
!—4
!—5
!—6
!—7
!—8
!—9
]=])
	for i = min_row, max_row do
		ins("|-\n")
		ins("! style='white-space: nowrap;' | " .. i .. "—\n")
		for j = 0, 9 do
			ins(j == 0 and "| " or "|| ")
			local num_data = m_number_list.lookup_data(m_data, tostring(i * 10 + j))
			local forms = num_data and num_data[args[2]]
			if forms then
				ins(link_forms(forms, m_data, lang))
			else
				ins("—")
			end
		end
		ins("\n")
	end
	ins("|}\n</div></div>")

	return table.concat(parts)
end

-- Called from [[Module:documentation/functions/number list]].
function export.table(frame)
	local language_code
	if type(frame) == "table" then
		language_code = frame.args[1]
	end

	local module
	if not language_code then
		module = mw.title.getCurrentTitle().fullText
		local suffix = module:match("^Module:number list/data/(.+)$")
		language_code = suffix:match "^([^/]+)/sandbox$" or suffix
		if not language_code then
			error("No language code in title or in parameter 1.")
		end
		if language_code == "und" then
			return
		end
	end

	local lang = require("Module:languages").getByCode(language_code, true)
	local m_data = require(module)
	return print_full_table(lang, m_data)
end

return export
