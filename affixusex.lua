local export = {}

local m_links = require("Module:links")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- helper functions

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- main function

function export.format_affixusex(lang, sc, parts, aftype)
	result = {}

	-- Loop over all terms. We simply call full_link() on each term, along with the
	-- associated params, to format the link, but need some special-casing for affixes.
	for index, part in ipairs(parts) do
		local term = part.term
		local alt = part.alt
		if term and (aftype == "prefix" or aftype == "affix") then
			if rfind(term, "^!.*%-$") then
				term = rsub(term, "^!", "")
			elseif rfind(term, "%-$") then
				alt = term
				term = nil
			end
		end
		if term and (aftype == "suffix" or aftype == "affix") then
			if rfind(term, "^!%-") then
				term = rsub(term, "^!", "")
			elseif rfind(term, "^%-") then
				alt = term
				term = nil
			end
		end

		if index == #parts or part.arrow then
			table.insert(result, " → &lrm;")
		elseif index > 1 then
			table.insert(result, " + &lrm;")
		end

		table.insert(result, m_links.full_link({
			lang = lang, sc = sc, term = term, gloss = part.t, tr = part.tr, ts = part.ts,
			genders = part.g and rsplit(part.g, ",") or {}, id = part.id, alt = alt,
			lit = part.lit, pos = part.pos, accel = part.accel
		}, "term"))

		if part.q then
			table.insert(result, " " .. require("Module:qualifier").format_qualifier(part.q))
		end
	end

	return table.concat(result)
end

return export
