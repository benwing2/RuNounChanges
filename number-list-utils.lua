local export = {}

-- Map a function over `list`, which may in fact be a list of strings or a single string. The return value of the
-- function may also be a single string or a list. If `list` is a list and the function returns a list, the results are
-- flattened into a single list. If `list` is a single string and the function returns a single string, the return
-- value of `map` will be a single string, otherwise a list. In all cases, when calling the function on a string, if
-- the string has modifiers (e.g. 'vuitanta-vuit<tag:Central>' or 'سیزده<tr:sizdah>'), the function is called on the
-- part without the modifiers, and the modifiers are then tacked onto the return value(s) of the function. Strings with
-- multiple modifiers such as 'سیزده<tr:sizdah><tag:Iranian>' are correctly handled.
function export.map(fun, list)
	if type(list) == "table" then
		local retval = {}
		for _, item in ipairs(list) do
			local mapret = export.map(fun, item)
			if type(mapret) == "table" then
				for _, ret in ipairs(mapret) do
					table.insert(retval, ret)
				end
			else
				table.insert(retval, mapret)
			end
		end
		return retval
	end
	local term_part, tag_part = list:match("^(.*)(<.->)$")
	if term_part then
		local mapret = export.map(fun, term_part)
		if type(mapret) == "table" then
			local retval = {}
			for _, ret in ipairs(mapret) do
				table.insert(retval, ret .. tag_part)
			end
			return retval
		else
			return mapret .. tag_part
		end
	end
	return fun(list)
end

function export.filter(fun, list, return_single_item)
	if type(list) ~= "table" then
		list = {list}
	end
	local retval = {}
	for _, item in ipairs(list) do
		if fun(item) then
			table.insert(retval, item)
		end
	end
	if return_single_item and #retval == 1 then
		retval = retval[1]
	end
	return retval
end

function export.power_of(n, base)
	return (base or 1) .. string.rep("0", n)
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

function export.add_thousands_separator(num, sep)
	num = export.format_fixed(num)
	if #num > 4 then
		local num_remainder_digits = #num % 3
		if num_remainder_digits == 0 then
			num_remainder_digits = 3
		end
		local left_remainder_digits = num:sub(1, num_remainder_digits)
		local right_power_of_3_digits = num:sub(1 + num_remainder_digits)
		num = left_remainder_digits .. right_power_of_3_digits:gsub("(...)", sep .. "%1")
	end
	return num
end

return export
