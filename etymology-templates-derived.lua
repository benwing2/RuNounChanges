local export = {}

local etymology_module = "Module:etymology"
local etymology_multi_module = "Module:etymology/multi"
local etymology_templates_internal_module = "Module:etymology/templates/internal"

function export.derived(frame)
	local args, lang, term, sources = require(etymology_templates_internal_module).parse_2_lang_args(frame)
	if sources then
		return require(etymology_multi_module).format_multi_derived {
			lang = lang,
			sc = term.sc,
			sources = sources,
			terminfo = term,
			sort_key = args.sort,
			nocat = args.nocat,
			conj = args.conj,
			template_name = "derived",
		}
	else
		return require(etymology_module).format_derived {
			lang = lang,
			terminfo = term,
			sort_key = args.sort,
			nocat = args.nocat,
			template_name = "derived",
		}
	end
end

return export
