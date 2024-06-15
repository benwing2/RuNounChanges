local export = {}

local m_links = require("Module:links")

local rsplit = mw.text.split

-- main function

function export.format_affixusex(lang, sc, parts)
	local result = {}

	-- Loop over all terms. We simply call full_link() on each term, along with the
	-- associated params, to format the link, but need some special-casing for affixes.
	for index, part in ipairs(parts) do
		local term = part.term
		local alt = part.alt

		if part.fulljoiner then
			table.insert(result, part.fulljoiner)
		elseif part.joiner then
			table.insert(result, " " .. part.joiner .. " ")
		elseif index == #parts or part.arrow then
			table.insert(result, " → ")
		elseif index > 1 then
			table.insert(result, " + ")
		end
		table.insert(result, "&lrm;")

		local terminfo = {
			lang = lang, sc = sc, term = term, gloss = part.t, tr = part.tr, ts = part.ts,
			genders = part.g and rsplit(part.g, ",") or {}, id = part.id, alt = alt,
			lit = part.lit, pos = part.pos, accel = part.accel
		}

		if part.q then
			table.insert(result, require("Module:qualifier").format_qualifier(part.q) .. " ")
		end

		if part.lang then
			terminfo.lang = part.lang
			terminfo.sc = part.sc
			table.insert(result, require("Module:etymology").format_derived(nil, terminfo, nil, "affixusex"))
		else
			table.insert(result, m_links.full_link(terminfo, "term"))
		end

		if part.qq then
			table.insert(result, " " .. require("Module:qualifier").format_qualifier(part.qq))
		end
	end

	return table.concat(result)
end

return export
