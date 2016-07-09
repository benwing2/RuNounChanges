--[=[
	This module implements the template {{given name}}.
]=]--

local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

local export = {}

local function ine(x) return x ~= "" and x; end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
		else args[pname] = param
		end
	end
	return args
end

local function join_names(lang, args, param, paramalt, paramtr)
	words = {}
	local val = args[param]
	local alt = args[paramalt]
	local tr = paramtr and args[paramtr]
	local i = 2

	while val do
		local sep = i == 2 and "" or not args[param .. i] and " or " or ", "
		local link = m_links.full_link({lang = lang, term = val, alt = alt, tr = tr})
		table.insert(list, val)
		val = args[param .. i]
		alt = args[paramalt .. i]
		tr = paramtr and args[paramtr .. i]
		i = i + 1
	end
	return table.concat(words, ""), i - 2
end

-- The main entry point.
function export.given_name(frame)
	local args = clone_args(frame)
	local textsegs = {}
	local lang = require("Module:languages").getByCode(args["lang"] or "en")
	local en = require("Module:languages").getByCode("en")
	local gender = args["gender"] or args[1] or "{{{1}}}"

	local dimtext, numdims = args["diminutive"] and
		join_names(lang, args, "diminutive", "diminutivealt", "diminutivetr") or
		join_names(lang, args, "dim", "dimalt", "dimtr") or
	local xlittext = join_names(en, args, "xlit", "xlitalt")
	local eqtext = join_names(en, args, "eq", "eqalt")

	table.insert(textsegs, "<span class='use-with-mention'>")
	table.insert(textsegs, (args["A"] or "A") .. " ")
	if numdims > 0 then
		table.insert(textsegs, "[[diminutive]]" .. (xlittext ~= "" and ", " .. xlittext .. "," or "") .. " of the ")
	end
	table.insert(textsegs, gender .. " " .. (
		args["or"] and "or " .. args["or"] .. " "))
	table.insert(textsegs, numdims > 1 and "[[given name|given names]]" or
		"[[given name]]")
	if numdims > 0 then
		table.insert(textsegs, " " .. dimtext)
	elseif xlittext ~= "" then
		table.insert(textsegs, ", " .. xlittext .. ",")
	end
	if eqtext ~= "" then
		table.insert(textsegs, ", equivalent to English " .. eqtext)
	end
	table.insert(textsegs, "</span>")

	local categories = {}
	local from = args["from"] or args[2]
	local langname = lang:getCanonicalName() .. " "
	table.insert(categories, langname ..
		(numdims > 0 and "diminutives of " or "") ..
		gender .. " given names" .. (from and " from " .. from))
	if args["or"] then
		table.insert(categories, langname .. args["or"] .. " given names" ..
			(from and " from " .. from))
	end

	return table.concat(textsegs, "") ..
		m_utilities.format_categories(categories, lang, args["sort"])
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
