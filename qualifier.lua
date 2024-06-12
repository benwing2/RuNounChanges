local export = {}

local concat = table.concat

function export.format_qualifier(list, open, close, opencontent, closecontent)
	if type(list) ~= "table" then
		list = {list}
	end

	if #list == 0 then
		return ""
	end

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	if open ~= false then
		ins("<span class=\"ib-brac qualifier-brac\">")
		ins(open or "(")
		ins("</span>")
	end
	ins(opencontent or "")
	ins("<span class=\"ib-content qualifier-content\">")
	ins(concat(list, "<span class=\"ib-comma qualifier-comma\">,</span> "))
	ins("</span>")
	ins(closecontent or "")
	if close ~= false then
		ins("<span class=\"ib-brac qualifier-brac\">")
		ins(close or ")")
		ins("</span>")
	end
	return concat(parts)
end

local function format_qualifier_with_clarification(list, clarification, open, close)
	local opencontent = "<span class=\"qualifier-clarification\">" .. clarification .. "</span>" .. 
		"<span class=\"qualifier-clarification qualifier-quote\">" .. (open or "“") .. "</span>"

	local closecontent = "<span class=\"qualifier-clarification qualifier-quote\">" .. (close or "”") .. "</span>"

	return export.format_qualifier(list, "(", ")", opencontent, closecontent)
end

function export.sense(list)
	return export.format_qualifier(list) .. "<span class=\"ib-colon sense-qualifier-colon\">:</span>"
end

function export.antsense(list)
	return format_qualifier_with_clarification(list, "antonym(s) of ") .. "<span class=\"ib-colon sense-qualifier-colon\">:</span>"
end

return export
