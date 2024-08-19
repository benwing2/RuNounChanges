local export = {}

local etymology_module = "Module:etymology"
local etymology_multi_module = "Module:etymology/multi"

local process_params = require("Module:parameters").process

do
	local function get_args(parent_args)
		local alias_of_t = {alias_of = "t"}
		local plain = {}
		return process_params(parent_args, {
			[1] = {
				required = true,
				sublist = true,
				type = "language",
				family = true,
				default = "und"
			},
			[2] = plain,
			[3] = {alias_of = "alt"},
			[4] = alias_of_t,
			["alt"] = plain,
			["conj"] = plain,
			["g"] = {list = true},
			["gloss"] = alias_of_t,
			["id"] = plain,
			["lit"] = plain,
			["pos"] = plain,
			["sc"] = {type = "script"},
			["sort"] = plain,
			["t"] = plain,
			["tr"] = plain,
			["ts"] = plain,
		})
	end
	
	function export.cognate(frame)
		local parent_args = frame:getParent().args
		
		if parent_args.gloss then
			require("Module:debug/track")("cognate/gloss param")
		end
		
		local args = get_args(parent_args)
		local sources = args[1]
	
		local terminfo = {
			lang = sources[#sources],
			sc = args["sc"],
			term = args[2],
			alt = args["alt"],
			id = args["id"],
			genders = args["g"],
			tr = args["tr"],
			ts = args["ts"],
			gloss = args["t"],
			pos = args["pos"],
			lit = args["lit"]
		}
	
		if #sources > 1 then
			return require(etymology_multi_module).format_multi_cognate {
				sources = sources,
				terminfo = terminfo,
				sort_key = args.sort,
				conj = args.conj,
			}
		end
		return require(etymology_module).format_cognate {
			terminfo = terminfo,
			sort_key = args.sort,
		}
	end
end

function export.noncognate(frame)
	return export.cognate(frame)
end

return export
