-- For internal use only with [[Module:etymology/templates]] and its submodules.
local process_params = require("Module:parameters").process

local export = {}

do
	local function get_params(frame, has_text, no_family)
		local alias_of_t = {alias_of = "t"}
		local boolean = {type = "boolean"}
		local plain = {}
		local params = {
			[1] = {
				required = true,
				type = "language",
				default = "und"
			},
			[2] = {
				required = true,
				sublist = true,
				type = "language",
				family = not no_family,
				default = "und"
			},
			[3] = plain,
			[4] = {alias_of = "alt"},
			[5] = alias_of_t,
			
			["alt"] = plain,
			["cat"] = plain,
			["g"] = {list = true},
			["gloss"] = alias_of_t,
			["id"] = plain,
			["lit"] = plain,
			["pos"] = plain,
			["t"] = plain,
			["tr"] = plain,
			["ts"] = plain,
			["sc"] = {type = "script"},
			["senseid"] = plain,
	
			["nocat"] = boolean,
			["sort"] = plain,
			["conj"] = plain,
		}
		if has_text then
			params["notext"] = boolean
			params["nocap"] = boolean
		end
		return process_params(frame:getParent().args, params)
	end
	
	function export.parse_2_lang_args(frame, has_text, no_family)
		local args = get_params(frame, has_text, no_family)
		local sources = args[2]
		return args, args[1], {
			lang = sources[#sources],
			sc = args["sc"],
			term = args[3],
			alt = args["alt"],
			id = args["id"],
			genders = args["g"],
			tr = args["tr"],
			ts = args["ts"],
			gloss = args["t"],
			pos = args["pos"],
			lit = args["lit"]
		}, #sources > 1 and sources or nil
	end
end

return export
