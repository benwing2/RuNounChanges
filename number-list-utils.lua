local export = {}

function export.map(fun, list)
	if type(list) == "table" then
		local retval = {}
		for _, item in ipairs(list) do
			table.insert(retval, export.map(fun, item))
		end
		return retval
	end
	local term_part, tag_part = list:match("^(.*)(<.->)$")
	if term_part then
		return export.map(fun, term_part) .. tag_part
	end
	return fun(list)
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
