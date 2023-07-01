local export = {}

local m_form_of = require("Module:form of")
local m_languages = require("Module:languages")

function export.inflection_inline_t(frame)
	local params = {
		[1] = {required = true},
		[2] = {required = true, list = true},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = m_languages.getByCode(args[1], 1)

	local outputs = {}
	local inputs = {}
	
	for _, tag in ipairs(args[2]) do
		if tag == ";" then
			if #inputs > 0 then
				table.insert(outputs, m_form_of.tagged_inflections({ tags = inputs, lang = lang }))
			end
			inputs = {}
		else
			table.insert(inputs, tag)
		end
	end

	if #inputs > 0 then
		table.insert(outputs, m_form_of.tagged_inflections({ tags = inputs, lang = lang }))
	end
	
	return table.concat(outputs, "; ")
end

return export
