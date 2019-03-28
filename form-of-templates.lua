local export = {}

function export.template_tags(frame)
	local iparams = {
		[1] = {list = true, required = true},
		["cat"] = {},
		["lang"] = {},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local compat = iargs["lang"] or frame:getParent().args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[1 + offset] = {required = true},
		[2 + offset] = {},
		[3 + offset] = {alias_of = "gloss"},
		
		["gloss"] = {},
		["t"] = {alias_of = "gloss"},
		["id"] = {},
		[compat and "lang" or 1] = {required = not iargs["lang"]},
		["nodot"] = {type = "boolean"},  -- does nothing right now, but used in existing entries
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
	}
	
	if iargs["cat"] then
		params["nocat"] = {type = "boolean"}
		params["sort"] = {}
	end
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = iargs["lang"] or args[compat and "lang" or 1] or "und"
	local sc = args["sc"]
	
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)
	
	if #iargs[1] == 1 and iargs[1][1] == "f" then
		require("Module:debug").track("feminine of/" .. lang:getCode())
	end
	
	local ret = require("Module:form of").tagged_inflections(iargs[1],
		{lang = lang, sc = sc, term = args[1 + offset] or "term", alt = args[2 + offset],
		 id = args["id"], gloss = args["gloss"], tr = args["tr"], ts = args["ts"]})
	
	if iargs["cat"] then
		if args["nocat"] then
			require("Module:debug").track("form of/" .. table.concat(iargs[1], "-") .. "/nocat")
		else
			require("Module:debug").track("form of/" .. table.concat(iargs[1], "-") .. "/cat")
			ret = ret .. require("Module:utilities").format_categories({lang:getCanonicalName() .. " " .. iargs["cat"]}, lang, args["sort"])
		end
	end
	
	return ret
end

function export.form_of_t(frame)
	local compat = frame:getParent().args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true},
		[1 + offset] = {required = true},
		[2 + offset] = {required = true},
		[3 + offset] = {},
		[4 + offset] = {alias_of = "gloss"},
		
		["dot"] = {},
		["gloss"] = {},
		["t"] = {alias_of = "gloss"},
		["id"] = {},
		["nodot"] = {type = "boolean"},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[compat and "lang" or 1] or "und"
	local sc = sc or args["sc"]
	
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)
	
	return require("Module:form of").format_t(
		(args[1 + offset] or "form") .. " of",
		{
			lang = lang,
			sc = sc,
			term = args[2 + offset] or "term",
			alt = args[3 + offset],
			id = args["id"],
			gloss = args["gloss"],
			tr = args["tr"],
			ts = args["ts"],
		}
	)
end

function export.inflection_of_t(frame)
	local compat = frame:getParent().args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true},
		[1 + offset] = {required = true},
		[2 + offset] = {},
		[3 + offset] = {list = true, required = true},
		
		["gloss"] = {},
		["t"] = {alias_of = "gloss"},
		["id"] = {},
		["nocap"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["nodot"] = {type = "boolean"},
		["pos"] = {},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[compat and "lang" or 1] or "und"
	local sc = args["sc"]
	
	lang = require("Module:languages").getByCode(lang) or
		require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or
		error("The script code \"" .. sc .. "\" is not valid.")) or nil)
	
	return require("Module:form of").tagged_inflections(
		args[3 + offset],
		{
			lang = lang,
			sc = sc,
			term = args[1 + offset] or "term",
			alt = args[2 + offset],
			id = args["id"],
			gloss = args["gloss"],
			pos = args["pos"],
			tr = args["tr"],
			ts = args["ts"],
		}
	)
end

return export
