local export = {numbers = {}}

local m_numutils = require("Module:number list/utils")
local power_of = m_numutils.power_of

local numbers = export.numbers

local function generate_number(cardinal)
	local root = cardinal:gsub("o$", "")
	return {
		cardinal = cardinal,
		ordinal = root .. "a",
		adverbial = root .. "e",
		multiplier = {root .. "obla", root .. "opa"},
		fractional = {root .. "ona", root .. "ono"},
	}
end

local function make_number(num, cardinal)
	numbers[num] = generate_number(cardinal)
end

local function append_number(number, number2)
	for _, numtyp in ipairs { "cardinal", "ordinal", "adverbial", "multiplier", "fractional" } do
		if not number[numtyp] then
			number[numtyp] = {}
		elseif type(number[numtyp]) ~= "string" then
			number[numtyp] = {number[numtyp]}
		end
		local forms = number2[numtyp]
		if type(forms) ~= "table" then
			forms = {forms}
		end
		for _, form in ipairs(forms) do
			table.insert(number[numtyp], form)
		end
	end
end

local function make_number_with_alts(num, card1, card2)
	local number1 = generate_number(num, card1)
	local number2 = generate_number(num, card2)
	append_number(number1, number2)
	numbers[num] = number1
end

numbers[0] = {
	cardinal = "nul",
	ordinal = "nula",
}

make_number(1, "unu")
make_number(2, "du")
make_number(3, "tri")
make_number(4, "kvar")
make_number(5, "kvin")
make_number(6, "ses")
make_number(7, "sep")
make_number(8, "ok")
make_number(9, "naŭ")

for i = 1, 9 do
	local tens_cardinal = "dek"
	if i ~= 1 then
		tens_cardinal = numbers[i].cardinal .. "dek"
		numbers[i * 10] = {
			cardinal = tens_cardinal,
			ordinal = tens_cardinal .. "a",
		}
		
		numbers[i * 100] = {
			cardinal = numbers[i].cardinal .. "cent",
			ordinal = numbers[i].cardinal .. "centa",
		}
	end
	
	for ones = 1, 9 do
		numbers[i * 10 + ones] = {
			cardinal = tens_cardinal .. " " .. numbers[ones].cardinal,
			ordinal = tens_cardinal .. "-" .. numbers[ones].cardinal .. "a",
		}
	end
end

make_number(10, "dek")
for ones = 1, 9 do
	make_number(ones * 100, numbers[ones].cardinal .. "cent")
end

make_number(100, "cent")
make_number(1000, "mil")
make_number(1000000, "miliono")
make_number(power_of(9), "miliardo")
make_number_with_alts(power_of(12), "duiliono", "biliono")
make_number(power_of(15), "duiliardo")
make_number_with_alts(power_of(18), "triiliono", "triliono")
make_number(power_of(21), "triiliardo")
make_number(power_of(24), "kvariliono")
make_number(power_of(27), "kvariliardo")
make_number_with_alts(power_of(30), "kviniliono", "kvintiliono")
make_number(power_of(33), "kviniliardo")
make_number(power_of(36), "sesiliono")
make_number(power_of(39), "sesiliardo")
make_number(power_of(42), "sepiliono")
make_number(power_of(45), "sepiliardo")
make_number(power_of(48), "okiliono")
make_number(power_of(51), "okiliardo")
make_number(power_of(54), "naŭiliono")
make_number(power_of(57), "naŭiliardo")
make_number(power_of(60), "dekiliono")
make_number(power_of(63), "dekiliardo")

return export
