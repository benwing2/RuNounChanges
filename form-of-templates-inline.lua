local export = {}

local m_form_of = require("Module:User:Benwing2/form of")
local m_languages = require("Module:languages")

function export.inflection_inline_t(frame)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {required = true, list = true},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = m_languages.getByCode(args[1], 1)

	local tags = args[2]
	if #tags == 0 and mw.title.getCurrentTitle().nsText == "Template" then
		tags = {"m", "acc", "s"}
	end

	local outputs = {}
	local tag_sets = m_form_of.split_tags_into_tag_sets(tags)

	-- Set nocat = true so we don't generate any categories; {{qinfl}} is used to generate qualifier tags and any
	-- associated categories may or may not apply to the page as a whole.
	for _, tag_set in ipairs(tag_sets) do
		table.insert(outputs, (m_form_of.tagged_inflections({ tags = tag_set, lang = lang, nocat = true })))
	end

	return table.concat(outputs, "; ")
end

return export
