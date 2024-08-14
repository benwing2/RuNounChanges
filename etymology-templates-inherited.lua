local export = {}

function export.inherited(frame)
	local args, lang, term, sources = require("Module:etymology/templates/internal").parse_2_lang_args(frame, nil, "no family")
	if sources then
		-- Because this doesn't really make sense.
		error("[[Template:inherited]] doesn't support multiple comma-separated sources")
	end
	return require("Module:etymology").format_inherited(lang, term, args["sort"], args["nocat"])
end

return export
