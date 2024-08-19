local export = {}

local etymology_module = "Module:etymology"
local etymology_templates_internal_module = "Module:etymology/templates/internal"

function export.inherited(frame)
	local args, lang, term, sources = require(etymology_templates_internal_module).parse_2_lang_args(frame, nil, "no family")
	if sources then
		-- Because this doesn't really make sense.
		error("[[Template:inherited]] doesn't support multiple comma-separated sources")
	end
	return require(etymology_module).format_inherited {
		lang = lang,
		terminfo = term,
		sort_key = args["sort"],
		nocat = args["nocat"],
	}
end

return export
