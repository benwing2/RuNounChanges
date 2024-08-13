local export = {}

function export.derived(frame)
	local args, lang, term, sources = require("Module:etymology/templates/internal").parse_2_lang_args(frame)
	if sources then
		return require("Module:etymology/multi").format_multi_derived(lang, term.sc, sources, term, args.sort,
			args.nocat, args.conj, "derived")
	else
		return require("Module:etymology").format_derived(lang, term, args.sort, args.nocat, "derived")
	end
end

return export
