local export = {}

function export.paramdoc_t(frame)
	local params = {
		["sgdescwithart"] = {},
		["art"] = {},
		["withfrom"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["withcap"] = {type = "boolean"},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)

	return require("Module:form of doc").paramdoc(args)
end

return export
