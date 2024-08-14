local export = {}

function export.borrowed(frame)
	local args, lang, term, sources = require("Module:etymology/templates/internal").parse_2_lang_args(frame)
	if sources then
		return require("Module:etymology/multi").format_multi_borrowed(lang, term.sc, sources, term, args.sort, args.nocat, args.conj)
	else
		return require("Module:etymology").format_borrowed(lang, term, args.sort, args.nocat)
	end
end

return export
