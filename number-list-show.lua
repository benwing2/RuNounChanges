local export = {}

local m_number_list = require("Module:number list")
local m_links = require("Module:links")

local function compare_numbers(a, b)
	a, b = tonumber(a),  tonumber(b)
	return a < b
end

local function link(lang, form)
	local term, translit, qualifier = m_number_list.split_term_and_translit_and_qualifier(form)
	return m_links.full_link({ lang = lang, term = term, tr = translit }) .. m_number_list.format_qualifier(qualifier)
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

function export.number_table(frame)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {required = true, default = "cardinal"},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	local langcode = args[1]
	local lang = require("Module:languages").getByCode(langcode, 1)
	local m_data = require(m_number_list.get_data_module_name(langcode))

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
		ins("|- align=right\n")
		ins("! style='white-space: nowrap;' | " .. i .. "—\n")
		for j = 0, 9 do
			ins(j == 0 and "| " or "|| ")
			local num_data = m_number_list.lookup_data(m_data, tostring(i * 10 + j))
			local forms = num_data and num_data[args[2]]
			if forms then
				if type(forms) == "table" then
					local formparts = {}
					for _, form in ipairs(forms) do
						table.insert(formparts, link(lang, form))
					end
					ins(table.concat(formparts, ", "))
				else
					ins(link(lang, forms))
				end
			else
				ins("—")
			end
		end
		ins("\n")
	end
	ins("|}\n</div></div>")

	return table.concat(parts)
end

function export.print_table(language_code, module)
	local module = require(module)
	
	local lang = require("Module:languages").getByCode(language_code)
	local full_link = require("Module:links").full_link
	local tag_text = require("Module:script utilities").tag_text
	local function tag(form)
		return tag_text(form, lang)
	end
	
	local form_types = m_number_list.get_number_types(language_code)
	local numeral_index = 1
	table.insert(form_types, numeral_index,
		{key = "numeral", display = "Numeral"})
	
	local number_type_indices = {}
	for number, data in pairs(module.numbers) do
		for i, form_type in pairs(form_types) do
			if data[form_type.key] then
				number_type_indices[i] = true
			end
		end
	end
	
	local numeral_config = module.numeral_config
	if numeral_config then
		number_type_indices[numeral_index] = true
	end
	
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
	
	for number, data in require("Module:table").sortedPairs(module.numbers, compare_numbers) do
		local number_string = m_number_list.format_fixed(number)

		row(m_number_list.add_thousands_separator(number_string, ","))
		
		local numeral
		if numeral_config then
			numeral = m_number_list.generate_decimal_numeral(numeral_config, number_string)
		elseif data.numeral then
			numeral = data.numeral
		end
		if numeral then
			numeral = tag(numeral)
			cell(numeral or "")
		end
		
		for _, i in ipairs(number_type_indices) do
			if i ~= numeral_index then
				local form = data[form_types[i].key]
				cell(type(form) == "table" and Array(form):map(function(f) return link(lang, f) end):concat(", ")
					or form and link(lang, form)
					or "")
			end
		end
		
		-- Check for numerical indices, which are syntax errors.
		for i, word in ipairs(data) do
			errors:insert({ number = number_string, word = word })
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
						return data.number .. ": " .. link(lang, data.word)
					end)
				:concat ", "
			.. "[[Category:Errors in number data modules|"
			.. lang:getCode() .. "]]</span>")
	end
	
	return output:concat("\n")
end

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
	
	return export.print_table(language_code, module)
end

return export
