local export = {}

local m_links = require("Module:links")

local form_types = {
	{key = "cardinal", display = "[[cardinal number|Cardinal]]"},
	{key = "ordinal", display = "[[ordinal number|Ordinal]]"},
	{key = "ordinal_abbr", display = "[[ordinal number|Ordinal]] [[abbreviation]]"},
	{key = "adverbial", display = "[[adverbial number|Adverbial]]"},
	{key = "multiplier", display = "[[multiplier|Multiplier]]"},
	{key = "distributive", display = "[[distributive number|Distributive]]"},
	{key = "collective", display = "[[collective number|Collective]]"},
	{key = "fractional", display = "[[fractional|Fractional]]"},
}

-- Keys in a `numbers` entry that aren't form types.
local non_form_types = {
	numeral = true,
	wplink = true,
}

local function track(page)
	require("Module:debug/track")("number list/" .. page)
	return true
end

function export.get_data_module_name(language_code)
	return "Module:User:Benwing2/number list/data/" .. language_code
end

local function power_of(n)
	return "1" .. string.rep("0", n)
end

function export.parse_term_and_modifiers(data_module_term)
	local retval = {}
	local term
	term = data_module_term
	while true do
		local new_term, angle_bracketed = term:match("^(.-)(%b<>)$")
		if not new_term then
			break
		end
		local prefix, content = angle_bracketed:match "^<(%w+):(.+)>$"
		if not prefix then
			break
		end
		if prefix == "q" or prefix == "qq" or prefix == "tr" or prefix == "tag" then
			retval[prefix] = content
		else
			error(("Unrecognized modified '%s' in data module term: %s"):format(prefix, data_module_term))
		end
		term = new_term
	end
	retval.term = term
	return retval
end

local function get_term(data_module_term)
	return export.parse_term_and_modifiers(data_module_term).term
end

-- Construct a map from number forms to a description object (a two-element list of {TYPE, NUMBER}). If the same form
-- corresponds to more than one number, the table contains a list of description objects; otherwise it just contains a
-- description object directly.
local function construct_form_to_type_and_number(lang, number_data)
	local form_to_data = {}
	local function ins_type_and_number(form, typ, num)
		form = lang:makeEntryName(get_term(form))
		local newel = {typ, num}
		if form_to_data[form] then
			local existing = form_to_data[form]
			if type(existing) == "table" and type(existing[1]) == "table" then
				-- already a list of elements; insert if not already present
				local already_seen = false
				for _, existel in ipairs(existing) do
					if existel[1] == typ and existel[2] == num then
						already_seen = true
						break
					end
				end
				if not already_seen then
					table.insert(existing, newel)
				end
			elseif existing[1] == typ and existing[2] == num then
				-- already present for this number and type (possible if terms differ but entry names are the same)
			else
				form_to_data[form] = {existing, newel}
			end
		else
			form_to_data[form] = newel
		end
	end

	for num, numdata in pairs(number_data) do
		for numtype, forms in pairs(numdata) do
			if non_form_types[numtype] then
				-- do nothing
			elseif type(forms) == "table" then
				for _, form in ipairs(forms) do
					ins_type_and_number(form, numtype, num)
				end
			else
				ins_type_and_number(forms, numtype, num)
			end
		end
	end

	return form_to_data
end

function export.lookup_number_by_form(lang, m_data, str)
	if not m_data.form_to_number then
		m_data.form_to_number = construct_form_to_type_and_number(lang, m_data.numbers)
	end

	return m_data.form_to_number[lang:makeEntryName(str)]
end

function export.lookup_data(m_data, numstr)
	-- Don't try to convert very large numbers to Lua numbers because they may overflow.
	-- Powers of 10 >= 10^22 cannot be represented exactly as a Lua number.
	return m_data.numbers[numstr] or #numstr < 22 and m_data.numbers[tonumber(numstr)] or nil
end

local function index_of_number_type(t, type)
	for i, subtable in ipairs(t) do
		if subtable.key == type then
			return i
		end
	end
end

-- additional_types is an array of tables like form_types,
-- but each table can contain the keys "before" or "after", which specify
-- the numeral type that the form should appear before or after.
-- The transformations are applied in order.
local function add_form_types(additional_types)
	local types = require "Module:table".deepcopy(form_types)
	for _, type in ipairs(additional_types) do
		type = require "Module:table".shallowcopy(type)
		local i
		if type.before or type.after then
			i = index_of_number_type(types, type.before or type.after)
		end
		-- For now, simply log an error message
		-- if the "before" or "after" number type was not found,
		-- and insert the number type at the end.
		if i then
			if type.before then
				table.insert(types, i - 1, type)
			else
				table.insert(types, i + 1, type)
			end
		else
			table.insert(types, type)
			if type.before or type.after then
				mw.log("Number type "
					.. (type.before or type.after)
					.. " was not found.")
			end
		end
		type.before, type.after = nil, nil
	end
	return types
end

function export.get_number_types(language_code)
	local m_data = require(export.get_data_module_name(language_code))
	local final_form_types = form_types
	if m_data.additional_number_types then
		final_form_types = add_form_types(m_data.additional_number_types)
	end
	return final_form_types
end

function export.display_number_type(number_type)
	if number_type.display then
		return number_type.display
	else
		return (number_type.key:gsub("^.", string.upper):gsub("_", " "))
	end
end

local function maybe_unsuffix(m_data, term)
	if not m_data.unsuffix then
		return term
	end
	for _, entry in ipairs(m_data.unsuffix) do
		local from, to = unpack(entry)
		term = mw.ustring.gsub(term, from, to)
	end
	return term
end

-- Group digits with a separator, such as a comma or a period. See [[w:Digit grouping]].
local function add_separator(numstr, separator, group, start)
	start = start or group
	if start >= #numstr then
		return numstr
	end

	local parts = { numstr:sub(-start) }
	for i = start + 1, #numstr, group do
		table.insert(parts, 1, numstr:sub(-(i + group - 1), -i))
	end

	return table.concat(parts, separator)
end

function export.add_thousands_separator(numstr, separator)
	if #numstr < 4 then -- < 1000
		return numstr
	end
	return add_separator(numstr, separator or ",", 3)
end

local function add_Indic_separator(numstr, separator)
	return add_separator(numstr, separator, 2, 3)
end

-- Convert a number (represented as a string) to non-Arabic form based on the specs in `numeral_config`.
-- This is used, for example, to display the Hindu, Eastern Arabic or Roman form of a number along with the standard
-- Arabic form. Most of the code below assumes that the non-Arabic numerals are decimal, and the digits map one-to-one
-- with Arabic numerals. If this is not the case (e.g. for Roman numerals), a special module function is called to do
-- the conversion.
function export.generate_non_arabic_numeral(numeral_config, numstr)
	-- `numstr` is a number represented as a string. See comment near top of show_box().
	if numeral_config.module and numeral_config.func then
		return require("Module:" .. numeral_config.module)[numeral_config.func](numstr)
	end

	local thousands_separator, Indic_separator, zero_codepoint =
		numeral_config.thousands_separator,
		numeral_config.Indic_separator,
		numeral_config.zero_codepoint

	if not zero_codepoint then
		return nil
	end

	if thousands_separator then
		numstr = export.add_thousands_separator(numstr, thousands_separator)
	elseif Indic_separator then
		numstr = add_Indic_separator(numstr, Indic_separator)
	end

	return numstr:gsub("[0-9]", function (digit)
		return mw.ustring.char(zero_codepoint + tonumber(digit))
	end)
end

-- Format a number (either a Lua number or a string) in fixed point without any decimal point or scientific notation.
-- `tostring()` doesn't work because it converts large numbers such as 1000000000000000 to "1e+15".
function export.format_fixed(number)
	if type(number) == "string" then
		return number
	else
		return ("%.0f"):format(number)
	end
end

-- Format a number (either a Lua number or a string) for display. Sufficiently small numbers are displayed in fixed
-- point with thousands separators. Larger numbers are displayed in both fixed point and scientific notation using
-- superscripts, and sufficiently large numbers are displayed only in scientific notation.
function export.format_number_for_display(number)
	local MAX_NUM_DIGITS_FOR_FIXED_ONLY = 6
	local MIN_NUM_DIGITS_FOR_SCIENTIFIC_ONLY = 13
	local numstr = export.format_fixed(number)
	local fixed = export.add_thousands_separator(numstr)
	if #numstr <= MAX_NUM_DIGITS_FOR_FIXED_ONLY then
		return fixed
	end
	local kstr = numstr:match("^([0-9]*[1-9])0*$")
	if not kstr then
		error("Internal error: Unable to match number '" .. numstr .. "'")
	end
	local exponent = ("10<sup>%s</sup>"):format(#numstr - 1)
	local mantissa
	if kstr == "1" then
		mantissa = ""
	elseif #kstr == 1 then
		mantissa = kstr .. " x "
	else
		mantissa = kstr:gsub("^([0-9])", "%1.") .. " x "
	end
	local scientific = mantissa .. exponent
	if #numstr >= MIN_NUM_DIGITS_FOR_SCIENTIFIC_ONLY then
		return scientific
	else
		return fixed .. " (" .. scientific .. ")"
	end
end

-- Return true if a < b, where either may be a Lua number or the string representation of a number.
function export.numbers_less_than(a, b)
	a, b = export.format_fixed(a), export.format_fixed(b)
	local alen = #a
	local blen = #b
	if alen < blen then
		return true
	end
	if alen > blen then
		return false
	end
	return a < b
end

function export.group_numeral_forms_by_tag(forms, pagename, m_data, lang)
	local seen_forms = {}
	local forms_by_tag = {}
	local seen_tags = {}
	local cur_tag

	for _, form in ipairs(forms) do
		local formobj = export.parse_term_and_modifiers(form)
		table.insert(seen_forms, formobj)
		local tag = formobj.tag or ""
		-- If this number is the current page, then store the tag for later use
		if not cur_tag and pagename then
			local entry_name = lang:makeEntryName(formobj.term)
			if (entry_name == pagename or maybe_unsuffix(m_data, entry_name) == pagename) then
				cur_tag = tag
			end
		end
		if not forms_by_tag[tag] then
			table.insert(seen_tags, tag)
			forms_by_tag[tag] = {}
		end
		table.insert(forms_by_tag[tag], formobj)
	end

	return seen_forms, forms_by_tag, seen_tags, cur_tag
end

function export.format_formobj(formobj, m_data, lang)
	local left_q = formobj.q and require("Module:qualifier").format_qualifier(formobj.q) .. " " or ""
	local right_q = formobj.qq and " " .. require("Module:qualifier").format_qualifier(formobj.qq) or ""
	return left_q .. m_links.full_link({
		lang = lang, term = maybe_unsuffix(m_data, formobj.term), alt = formobj.term, tr = formobj.tr,
	}) .. right_q
end

function export.show_box(frame)
	local full_link = m_links.full_link

	local params = {
		[1] = {required = true},
		[2] = {},
		["pagename"] = {},
		["type"] = {},
	}

	local parent_args = frame:getParent().args
	if parent_args.pagename then
		track("show-box-pagename")
	end
	local args = require("Module:parameters").process(parent_args, params)

	local langcode = args[1] or "und"
	local lang = require("Module:languages").getByCode(langcode, "1")

	-- Get the data from the data module. [[Module:number list/data/en]] has to be loaded with require because its
	-- exported numbers table has a metatable.
	local module_name = export.get_data_module_name(langcode)
	local m_data = require(module_name)

	local pagename = args.pagename or (mw.title.getCurrentTitle().nsText == "Reconstruction" and "*" or "") .. mw.title.getCurrentTitle().subpageText

	local cur_type

	-- We represent all numbers as strings in this function to deal with the limited precision inherent in Lua numbers.
	-- These large numbers do occur, such as 100 trillion ([[རབ་བཀྲམ་ཆེན་པོ]]), 1 sextillion, etc. Lua represents all
	-- numbers as 64-bit floats, meaning that some numbers above 2^53 cannot be represented exactly. The first power of
	-- 10 that cannot be represented exactly is 10^22 (ten sextillion in short scale, ten thousand trillion in long
	-- scale), but the first power of ten whose neighboring numbers cannot be represented exactly is 10^16 (ten
	-- quadrillion or ten thousand billion). Ideally we would use a big integer library of some kind, but unfortunately
	-- Wiktionary does not seem to have any such library installed. MediaWiki docs make mention of bcmath, but
	-- mw.bcmath.new() throws an error.
	--
	-- In module data, we allow numbers to be indexed as Lua numbers or as strings. See lookup_data() below.
	local cur_num = args[2] or langcode == "und" and mw.title.getCurrentTitle().nsText == "Template" and "2" or nil
	if not cur_num then
		local type_and_num = export.lookup_number_by_form(lang, m_data, pagename)
		if not type_and_num then
			error("The current page name '" .. pagename .. "' does not match the spelling of any known number in [[" ..
				module_name .. "]]. Check the data module or the spelling of the page.")
		end
		if type(type_and_num) == "table" and type(type_and_num[1]) == "table" then
			local errparts = {}
			for _, type_num in ipairs(type_and_num) do
				local typ, num = unpack(type_num)
				table.insert(errparts, ("%s (%s)"):format(typ, num))
			end
			error("The current page name '" .. pagename .. "' matches the spelling of multiple numbers in [[" ..
				module_name .. "]]: " .. table.concat(errparts, ",") .. ". Please specify the number explicitly.")
		end
		cur_type, cur_num = unpack(type_and_num)
		cur_num = export.format_fixed(cur_num)
	end

	cur_type = args.type or cur_type
	cur_num = cur_num:gsub(",", "") -- remove thousands separators
	if not cur_num:find "^%d+$" then
		error("Extraneous characters in parameter 2: should be decimal number (integer): '" .. cur_num .. "'")
	end

	local function lookup_data(numstr)
		return export.lookup_data(m_data, numstr)
	end

	local cur_data = lookup_data(cur_num)

	if not cur_data then
		error('The number "' .. cur_num .. '" is not found in the "numbers" table in [[' .. module_name .. "]].")
	end

	-- Go over each number and make links
	local formatted_forms = {}

	if cur_type and not cur_data[cur_type] then
		error("The numeral type " .. cur_type .. " for " .. cur_num .. " is not found in [[" .. module_name .. "]].")
	end

	local cur_tag

	local forms_by_tag_per_form_type = {}
	local seen_tags_per_form_type = {}

	local form_types = export.get_number_types(langcode)

	for _, form_type in ipairs(form_types) do
		local numeral = cur_data[form_type.key]
		if numeral then
			local numerals
			if type(numeral) == "string" then
				numerals = {numeral}
			elseif type(numeral) == "table" then
				numerals = numeral
			end

			local seen_forms, forms_by_tag, seen_tags, this_cur_tag = export.group_numeral_forms_by_tag(numerals, pagename, m_data, lang)
			forms_by_tag_per_form_type[form_type] = forms_by_tag
			seen_tags_per_form_type[form_type] = seen_tags
			if this_cur_tag and not cur_type then
				cur_type = form_type.key
			end
			cur_tag = cur_tag or this_cur_tag
		end
	end
	
	for _, form_type in ipairs(form_types) do
		local forms_by_tag = forms_by_tag_per_form_type[form_type]
		local seen_tags = seen_tags_per_form_type[form_type]
		if forms_by_tag then
			local function insert_forms_by_tag(tag)
				local formatted_tag_forms = {}

				for _, formobj in ipairs(forms_by_tag[tag]) do
					table.insert(formatted_tag_forms, export.format_formobj(formobj, m_data, lang))
				end

				local displayed_number_type = export.display_number_type(form_type) .. (tag == "" and "" or (" (%s)"):format(tag))
				if form_type.key == cur_type and tag == cur_tag then
					displayed_number_type = "'''" .. displayed_number_type .. "'''"
				end

				table.insert(formatted_forms, " &nbsp;&nbsp;&nbsp; ''" .. displayed_number_type .. "'': " ..
					table.concat(formatted_tag_forms, ", "))
			end

			if cur_tag and forms_by_tag[cur_tag] then
				insert_forms_by_tag(cur_tag)
			end
			for _, tag in ipairs(seen_tags) do
				if tag ~= cur_tag then
					insert_forms_by_tag(tag)
				end
			end
		end
	end

	if not cur_type and mw.title.getCurrentTitle().nsText ~= "Template" then
		error("The current page name '" .. pagename .. "' does not match any of the numbers listed in [[" ..
			module_name .. "]] for " .. cur_num .. ". Check the data module or the spelling of the page.")
	end

	-- Current number in header
	local cur_display = export.format_number_for_display(cur_num)

	local numeral
	if m_data.numeral_config then
		numeral = export.generate_non_arabic_numeral(m_data.numeral_config, cur_num)
	elseif cur_data["numeral"] then
		numeral = export.format_fixed(cur_data["numeral"])
	end

	if numeral then
		cur_display = full_link({lang = lang, alt = numeral, tr = "-"}) .. "<br/><span style=\"font-size: smaller;\">" .. cur_display .. "</span>"
	end

	-- We want a series of numbers like this:
	-- 1, 2, ..., 9, 10, 11, 12, ..., 99, 100, 200, ..., 900, 1000, 2000, ..., 9000, 10000, 20000, ..., etc.
	--
	-- The general principle is as follows, for a number N:
	-- 1. Decompose the number into K followed by M zeros.
	-- 2. If M < 2, the next number of N + 1, and the previous number is N - 1.
	-- 3. Otherwise, if K isn't 1, the next number is K + 1 followed by M zeros, and the previous number is K - 1
	--    followed by M zeros.
	-- 4. Otherwise, K == 1; if M == 2, the next number of formed the same as in (2) and the previous number is N - 1.
	-- 5. Otherwise, next number of formed the same as in (2), but the previous number is formed by 9 followed by
	--    M - 1 zeros.
	--
	-- This works for numbers not in the above series; e.g. 45000 has 46000 as its previous number and 44000 as its
	-- next number, while 45310 has 45311 as its next number and 45309 as its previous number.
	--
	-- If the next higher number in the series doesn't have an entry in the table, and the number is an exact power of
	-- 10, look for a higher power of 10, up to 10^6 times greater. Similarly for next lower numbers.
	--
	-- We also display "outer numbers" in some circumstances, according to the following series:
	-- 0; 10; 20; ...; 90; 100; 1,000; 10,000; 100,000; 1,000,000; 10,000,000; 100,000,000; 1,000,000,000; ...
	--
	-- We only try to find outer numbers if the number has at most one zero at the end (in which case we check 10 above
	-- and below) or if it's an exact power of 10. If the number is an exact power of 10, and >= 1000, we proceed as
	-- follows to find the next higher outer number:
	--
	-- 1. Check the next-higher power of 10 if it's greater than the next higher number determined in the first part
	--    above.
	-- 2. Check the next-higher power of 10 that's an exact multiple of 3 if it's greater than the number just checked
	--    and also greater than the next higher number determined in the first part above.
	-- 3. Check the next-higher power of 10 that's an exact multiple of 6 if it's greater than the number just checked
	--    and also greater than the next higher number determined in the first part above.
	--
	-- Similarly for the next lower outer number.
	local next_data, prev_data
	local next_num, prev_num
	local next_outer_data, prev_outer_data
	local next_outer_num, prev_outer_num
	if cur_num == "0" then
		next_num = "1"
		next_data = lookup_data(next_num)
		next_outer_num = "10"
		next_outer_data = lookup_data(next_outer_num)
	else
		local kstr, mstr = cur_num:match("^([0-9]*[1-9])(0*)$")
		if not kstr then
			error("Internal error: Unable to match number '" .. cur_num .. "'")
		elseif #kstr > 15 then
			-- This is because some numbers with 16 or more digits can't be represented exactly.
			error("Can't handle number with more than 15 digits before the trailing zeros: '" .. cur_num .. "'")
		end
		local k = tonumber(kstr)
		local m = #mstr
		if m < 2 then -- less than two zeros at the end
			next_num = export.format_fixed(tonumber(cur_num) + 1)
			prev_num = export.format_fixed(tonumber(cur_num) - 1)
			if m == 1 then
				next_outer_num = export.format_fixed(tonumber(cur_num) + 10)
				prev_outer_num = export.format_fixed(tonumber(cur_num) - 10)
			end
		else
			next_num = (k + 1) .. mstr
			if k ~= 1 then
				prev_num = (k - 1) .. mstr
			elseif m == 2 then -- = 100
				prev_num = "99"
			else
				prev_num = "9" .. string.rep("0", m - 1)
			end
		end

		next_data = lookup_data(next_num)
		if not next_data and k == 1 then
			-- Try looking up a greater power of ten instead, adding up to 6 zeros.
			for i = 1, 6 do
				next_num = cur_num .. string.rep("0", i)
				next_data = lookup_data(next_num)
				if next_data then
					break
				end
			end
		end

		prev_data = lookup_data(prev_num)
		if not prev_data and k == 1 then
			-- Try looking up a smaller power of ten instead, removing up to 6 zeros.
			for i = 1, 6 do
				local desired_zeros = m - i
				if desired_zeros < 0 then
					break
				end
				prev_num = power_of(desired_zeros)
				prev_data = lookup_data(prev_num)
				if prev_data then
					break
				end
			end
		end

		-- Now determine the "outer numbers" to display (if any).
		if m == 1 then
			next_outer_num = export.format_fixed(tonumber(cur_num) + 10)
			next_outer_data = lookup_data(next_outer_num)
			prev_outer_num = export.format_fixed(tonumber(cur_num) - 10)
			prev_outer_data = lookup_data(prev_outer_num)
		elseif m >= 2 and k == 1 then
			-- for numbers with two or more zeros at the end, only display outer numbers if they're an exact
			-- power of 10.
			local lower_numbers_to_check, higher_numbers_to_check
			-- Round n down to an even multiple of k. E.g. if k == 3, 3/4/5 -> 3, 6/7/8 -> 6, etc.
			local function round_down_to_even_multiple(n, k)
				return n - (n % k)
			end
			-- Round n up to an even multiple of k. E.g. if k == 3, 4/5/6 -> 6, 7/8/9 -> 9, etc.
			local function round_up_to_even_multiple(n, k)
				return round_down_to_even_multiple(n + k - 1, k)
			end
			if m == 2 then -- 100
				lower_numbers_to_check = {"90"}
				higher_numbers_to_check = {"1000"}
			else
				local prev_power = m - 1
				lower_numbers_to_check = {power_of(prev_power)}
				local prev_power_even_mod_3 = round_down_to_even_multiple(prev_power, 3)
				if prev_power_even_mod_3 ~= prev_power and prev_power_even_mod_3 > 0 then
					table.insert(lower_numbers_to_check, power_of(prev_power_even_mod_3))
				end
				local prev_power_even_mod_6 = round_down_to_even_multiple(prev_power, 6)
				if prev_power_even_mod_6 ~= prev_power_even_mod_3 then
					table.insert(lower_numbers_to_check, power_of(prev_power_even_mod_6))
				end
				local next_power = m + 1
				higher_numbers_to_check = {power_of(next_power)}
				local next_power_even_mod_3 = round_up_to_even_multiple(next_power, 3)
				if next_power_even_mod_3 ~= next_power and next_power_even_mod_3 > 0 then
					table.insert(higher_numbers_to_check, power_of(next_power_even_mod_3))
				end
				local next_power_even_mod_6 = round_up_to_even_multiple(next_power, 6)
				if next_power_even_mod_6 ~= next_power_even_mod_3 then
					table.insert(higher_numbers_to_check, power_of(next_power_even_mod_6))
				end
			end

			for _, outer_num in ipairs(higher_numbers_to_check) do
				if not next_data or export.numbers_less_than(next_num, outer_num) then
					next_outer_data = lookup_data(outer_num)
					if next_outer_data then
						next_outer_num = outer_num
						break
					end
				end
			end
			for _, outer_num in ipairs(lower_numbers_to_check) do
				if not prev_data or export.numbers_less_than(outer_num, prev_num) then
					prev_outer_data = lookup_data(outer_num)
					if prev_outer_data then
						prev_outer_num = outer_num
						break
					end
				end
			end
		end
	end

	-- Format the entry or entries associated with the current type of the number `num` (a string) with corresponding
	-- data entry `num_data`. `arrow` is text to be inserted between the number and the textual representation of the
	-- number. If `num_follows`, the number is appended after the textual representation; otherwise, before. Returns
	-- nil if `num_data` is nil or there is no entry in `num_data` for the current number type.
	local function display_entries(num, num_data, arrow, num_follows)
		if not num_data then
			return nil
		end
		local num_type_data = num_data[cur_type]
		if not num_type_data then
			return nil
		end
		local entries = num_type_data
		if type(entries) ~= "table" then
			entries = {entries}
		end

		local seen_forms, forms_by_tag = export.group_numeral_forms_by_tag(entries)

		local forms_to_display
		if cur_tag and forms_by_tag[cur_tag] then
			forms_to_display = forms_by_tag[cur_tag]
		else
			forms_to_display = seen_forms
		end

		for i, form_to_display in ipairs(forms_to_display) do
			forms_to_display[i] = maybe_unsuffix(m_data, form_to_display.term)
		end

		local seen_pagenames = {}
		local pagenames_to_display = {}
		for _, form in ipairs(forms_to_display) do
			form = lang:makeEntryName(form)
			if not seen_pagenames[form] then
				table.insert(pagenames_to_display, form)
				seen_pagenames[form] = true
			end
		end

		num = export.format_number_for_display(num)
		local num_arrow = num_follows and arrow .. num or num .. arrow
		if #pagenames_to_display > 1 then
			local a = ("a"):byte()
			local links = {}
			for i, term in ipairs(pagenames_to_display) do
				links[i] = m_links.language_link{lang = lang, term = term, alt = "[" .. string.char(a + i - 1) .. "]"}
			end
			links = "<sup>" .. table.concat(links, ", ") .. "</sup>"
			return num_follows and links .. num_arrow or num_arrow .. links
		else
			return m_links.language_link {
				lang = lang,
				term = pagenames_to_display[1],
				alt = num_arrow,
			}
		end
	end

	-- Link to previous number
	--
	--	Current format:
	--		if multiple entries:
	--			<sup>[a], [b], ...</sup> ← <numeral>
	--		else
	--			← <numeral>
	local prev_display = display_entries(prev_num, prev_data, "&nbsp;←&nbsp;&nbsp;", "num follows") or ""
	local prev_outer_display = display_entries(prev_outer_num, prev_outer_data, "&nbsp;←&nbsp;&nbsp;", "num follows")

	-- Link to next number
	--
	--	Current format:
	--		if multiple entries:
	--			<numeral> → <sup>[a], [b], ...</sup>
	--		else
	--			<numeral> →
	local next_display = display_entries(next_num, next_data, "&nbsp;&nbsp;→&nbsp;") or ""
	local next_outer_display = display_entries(next_outer_num, next_outer_data, "&nbsp;&nbsp;→&nbsp;")

	-- Link to number times ten and divided by ten
	-- Show this only if the number is a power of ten times a number 1-9 (that is, of the form x000...)
	local up_display
	local down_display

	if cur_num:find("^[1-9]0*$") then
		up_num = cur_num .. "0"
		if up_num ~= next_num then -- don't duplicate the next number (to the right) in the up number
			up_display = display_entries(up_num, lookup_data(up_num), "")
		end

		-- Only divide by 10 if the number is a multiple of 10
		if cur_num:find("0$") then
			local down_num = cur_num:gsub("0$", "")
			if down_num ~= prev_num then -- don't duplicate the previous number (to the left) in the down number
				down_display = display_entries(down_num, lookup_data(down_num), "")
			end
		end
	end

	local canonical_name = lang:getCanonicalName()
	local appendix1 = canonical_name .. " numerals"
	local appendix2 = canonical_name .. " numbers"
	local appendix
	local title
	if mw.title.new(appendix1, "Appendix").exists then
		appendix = appendix1
	elseif mw.title.new(appendix2, "Appendix").exists then
		appendix = appendix2
	end

	if appendix then
		title = "[[Appendix:" .. appendix .. "|" .. appendix2 .. "]]"
	else
		title = appendix2
	end

	local function format_cell(contents, font_size, background, colspan, bold)
		font_size = font_size and (" font-size:%s;"):format(font_size) or ""
		background = background and (" background:%s;"):format(background) or ""
		colspan = colspan and ('colspan="%s" '):format(colspan) or ""
		bold = bold and "!" or "|"
		return ('%s %sstyle="min-width: 6em;%s%s | %s\n'):format(bold, colspan, font_size, background, contents)
	end

	local has_outer_display = not not (prev_outer_display or next_outer_display)
	local function format_up_down_display_row(display)
		local blank_cell
		if has_outer_display then
			blank_cell = '| colspan="2" |\n'
		else
			blank_cell = "|\n"
		end
		local parts = {'|- style="text-align: center; background:#dddddd;"\n'}
		table.insert(parts, blank_cell)
		table.insert(parts, format_cell(display, "smaller"))
		table.insert(parts, blank_cell)
		return table.concat(parts)
	end

	up_display = up_display and format_up_down_display_row(up_display) or ""
	down_display = down_display and format_up_down_display_row(down_display) or ""

	local function format_display_cell(display)
		return format_cell(display, "smaller", "#dddddd")
	end

	prev_display = format_display_cell(prev_display)
	next_display = format_display_cell(next_display)
	prev_outer_display = has_outer_display and format_display_cell(prev_outer_display or "") or ""
	next_outer_display = has_outer_display and format_display_cell(next_outer_display or "") or ""
	cur_display = format_cell(cur_display, "larger", nil, nil, "bold")

	local forms_display = ('| colspan="%s" style="text-align: center;" | %s\n'):format(
		has_outer_display and 5 or 3, table.concat(formatted_forms, "<br/>"))

	local footer_display
	if cur_data.wplink then
		local footer =
			"[[w:" .. lang:getCode() .. ":Main Page|" .. lang:getCanonicalName() .. " Wikipedia]] article on " ..
			m_links.full_link({lang = lang, term = "w:" .. lang:getCode() .. ":" .. cur_data.wplink,
			alt = export.format_number_for_display(cur_num)})
		footer_display = '|- style="text-align: center;"\n' .. format_cell(footer, nil, "#dddddd", has_outer_display and 5 or 3)
	else
		footer_display = ""
	end

	local edit_link = ' <sup>(<span class="plainlinks">[' ..
		tostring(mw.uri.fullUrl(module_name, { action = "edit" })) ..
		" edit]</span>)</sup>"

	return [=[{| class="floatright" cellpadding="5" cellspacing="0" style="background: #ffffff; border: 1px #aaa solid; border-collapse: collapse; margin-top: .5em;" rules="all"
|+ ''']=] .. title .. edit_link .. "'''\n" ..
	up_display .. '|- style="text-align: center;"\n' ..
	prev_outer_display .. prev_display .. cur_display .. next_display .. next_outer_display .. "|-\n" ..
	down_display .. "|-\n" ..
	forms_display .. footer_display .. "|}"
end


-- Assumes string or nil (or false), the types that can be found in an args table.
local function if_not_empty(val)
	if val and mw.text.trim(val) == "" then
		return nil
	else
		return val
	end
end


function export.show_box_manual(frame)
	local m_links = require("Module:links")
	local num_type = frame.args["type"]

	local args = {}
	--cloning parent's args while also assigning nil to empty strings
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = if_not_empty(param)
	end

	local lang = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "und") or error("Language code has not been specified. Please pass parameter 1 to the template.")
	local sc = args["sc"];
	local headlink = args["headlink"]
	local wplink = args["wplink"]
	local alt = args["alt"]
	local tr = args["tr"]

	local prev_symbol = if_not_empty(args[2])
	local cur_symbol = if_not_empty(args[3]);
	local next_symbol = if_not_empty(args[4])

	local prev_term = if_not_empty(args[5])
	local next_term = if_not_empty(args[6])

	local cardinal_term = args["card"]; local cardinal_alt = args["cardalt"]; local cardinal_tr = args["cardtr"]

	local ordinal_term = args["ord"]; local ordinal_alt = args["ordalt"]; local ordinal_tr = args["ordtr"]

	local adverbial_term = args["adv"]; local adverbial_alt = args["advalt"]; local adverbial_tr = args["advtr"]

	local multiplier_term = args["mult"]; local multiplier_alt = args["multalt"]; local multiplier_tr = args["multtr"]

	local distributive_term = args["dis"]; local distributive_alt = args["disalt"]; local distributive_tr = args["distr"]

	local collective_term = args["coll"]; local collective_alt = args["collalt"]; local collective_tr = args["colltr"]

	local fractional_term = args["frac"]; local fractional_alt = args["fracalt"]; local fractional_tr = args["fractr"]

	local optional1_title = args["opt"]
	local optional1_term = args["optx"]; local optional1_alt = args["optxalt"]; local optional1_tr = args["optxtr"]

	local optional2_title = args["opt2"]
	local optional2_term = args["opt2x"]; local optional2_alt = args["opt2xalt"]; local optional2_tr = args["opt2xtr"]


	lang = require("Module:languages").getByCode(lang) or error("The language code \"" .. lang .. "\" is not valid.")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	track(lang:getCode())

	if sc then
		track("sc")
	end

	if headlink then
		track("headlink")
	end

	if wplink then
		track("wplink")
	end

	if alt then
		track("alt")
	end

	if cardinal_alt or ordinal_alt or adverbial_alt or multiplier_alt or distributive_alt or collective_alt or fractional_alt or optional1_alt or optional2_alt then
		track("xalt")
	end

	local lang_type = lang:getType()
	local subpage = mw.title.getCurrentTitle().subpageText
	local is_reconstructed = lang_type == "reconstructed" or mw.title.getCurrentTitle().nsText == "Reconstruction"
	alt = alt or (is_reconstructed and "*" or "") .. subpage

	if num_type == "cardinal" then
		cardinal_term = (is_reconstructed and "*" or "") .. subpage
		cardinal_alt = alt
		cardinal_tr = tr
	elseif num_type == "ordinal" then
		ordinal_term = (is_reconstructed and "*" or "") .. subpage
		ordinal_alt = alt
		ordinal_tr = tr
	end

	local header = lang:getCanonicalName() .. " " .. num_type .. " numbers"

	if headlink then
		header = "[[" .. headlink .. "|" .. header .. "]]"
	end

	local previous = ""

	if prev_term or prev_symbol then
		previous = m_links.full_link({lang = lang, sc = sc, term = prev_term, alt = "&nbsp;&lt;&nbsp;&nbsp;" .. prev_symbol, tr = "-"})
	end

	local current = m_links.full_link({lang = lang, sc = sc, alt = cur_symbol, tr = "-"})

	local next = ""

	if next_term or next_symbol then
		next = m_links.full_link({lang = lang, sc = sc, term = next_term, alt = next_symbol .. "&nbsp;&nbsp;&gt;&nbsp;", tr = "-"})
	end

	local forms = {}

	if cardinal_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[cardinal number|Cardinal]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = cardinal_term, alt = cardinal_alt, tr = cardinal_tr}))
	end

	if ordinal_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[ordinal number|Ordinal]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = ordinal_term, alt = ordinal_alt, tr = ordinal_tr}))
	end

	if adverbial_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[adverbial number|Adverbial]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = adverbial_term, alt = adverbial_alt, tr = adverbial_tr}))
	end

	if multiplier_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[multiplier|Multiplier]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = multiplier_term, alt = multiplier_alt, tr = multiplier_tr}))
	end

	if distributive_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[distributive number|Distributive]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = distributive_term, alt = distributive_alt, tr = distributive_tr}))
	end

	if collective_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[collective number|Collective]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = collective_term, alt = collective_alt, tr = collective_tr}))
	end

	if fractional_term then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''[[fractional|Fractional]]'' : " .. m_links.full_link({lang = lang, sc = sc, term = fractional_term, alt = fractional_alt, tr = fractional_tr}))
	end

	if optional1_title then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''" .. optional1_title .. "'' : " .. m_links.full_link({lang = lang, sc = sc, term = optional1_term, alt = optional1_alt, tr = optional1_tr}))
	end

	if optional2_title then
		table.insert(forms, " &nbsp;&nbsp;&nbsp; ''" .. optional2_title .. "'' : " .. m_links.full_link({lang = lang, sc = sc, term = optional2_term, alt = optional2_alt, tr = optional2_tr}))
	end

	local footer = ""

	if wplink then
		footer =
			"[[w:" .. lang:getCode() .. ":Main Page|" .. lang:getCanonicalName() .. " Wikipedia]] article on " ..
			m_links.full_link({lang = lang, sc = sc, term = "w:" .. lang:getCode() .. ":" .. wplink, alt = alt, tr = tr})
	end

	return [=[{| class="floatright" cellpadding="5" cellspacing="0" style="background: #ffffff; border: 1px #aaa solid; border-collapse: collapse; margin-top: .5em;" rules="all"
|+ ''']=] .. header .. [=['''
|-
| style="width: 64px; background:#dddddd; text-align: center; font-size:smaller;" | ]=] .. previous .. [=[

! style="width: 98px; text-align: center; font-size:larger;" | ]=] .. current .. [=[

| style="width: 64px; text-align: center; background:#dddddd; font-size:smaller;" | ]=] .. next .. [=[

|-
| colspan="3" style="text-align: center;" | ]=] .. table.concat(forms, "<br/>") .. [=[

|-
| colspan="3" style="text-align: center; background: #dddddd;" | ]=] .. footer .. [=[

|}]=]
end

return export
