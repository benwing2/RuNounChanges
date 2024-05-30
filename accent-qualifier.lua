local export = {}

local labels_module = "Module:labels"

--[==[
Format accent qualifiers. Implements the {{tl|a}} (shortcut for {{tl|accent}}) template. This template is now virtually
identical to a non-categorizing {{tl|lb}}, although a few labels display and/or link differently (e.g. Egyptian-language
label 'Old Egyptian' displays as "reconstructed Old Egyptian" instead of just "Old Egyptian", and English-language
label 'Australia' displays as "General Australian" instead of just "Australia", and links to
[[w:Australian English phonology]] instead of [[w:Australian English]]).
]==]
function export.format_qualifiers(lang, qualifiers)
	return require(labels_module).show_labels {
		lang = lang,
		labels = qualifiers,
		nocat = true,
		mode = "accent",
	}
end

--[==[
External entry point that implements {{tl|accent}} and {{tl|a}}.
]==]
function export.show(frame)
	if not frame.getParent then
		error("When calling [[Module:accent qualifier]] internally, use format_qualifiers() not show()")
	end
	local parent_args = frame:getParent().args

	local params = {
		[1] = {type = "language", etym_lang = true, default = "und"},
		[2] = {list = true, required = true, default = "{{{2}}}"},
	}
	local args = require("Module:parameters").process(parent_args, params)
	return export.format_qualifiers(args[1], args[2])
end

return export
