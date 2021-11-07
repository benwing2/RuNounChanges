local export = {}

local m_languages = require("Module:languages")
local m_links = require("Module:links")
local m_qual = require("Module:qualifier")

function export.show(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[1 + offset] = {list = true, allow_holes = true, required = false},
		
		[compat and "lang" or 1] = {required = true, default = "en"},
		["alt"] = {list = true, allow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["sort"] = {},
	}
	
	local args, unrecognized_args =
		require("Module:parameters").process(parent_args, params, true)
	
	if next(unrecognized_args) then
		local list = {}
		local tracking = { "homophones/unrecognized param" }
		for k, v in pairs(unrecognized_args) do
			table.insert(tracking, "homophones/unrecognized param/" .. tostring(k))
			table.insert(list, "|" .. tostring(k) .. "=" .. tostring(v))
		end
		require("Module:debug").track(tracking)
		mw.log("Unrecognized parameter" .. (list[2] and "s" or "")
			.. " in {{homophones}}: " .. table.concat(list, ", "))
	end
	
	local lang = args[compat and "lang" or 1]
	lang = m_languages.getByCode(lang) or m_languages.err(lang, 1)
	
	local maxindex = math.max(args[1 + offset].maxindex, args["alt"].maxindex, args["tr"].maxindex)
	
	-- done this way to maintain past behaivour
	if (args[1 + offset][1] == nil and args["alt"][1] == nil and args["tr"][1] == nil) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			-- so as not to cause an error on the template's page
			args[1 + offset][1] = "term"
		else
			error("Please provide at least one homophone.")
		end
	end
	
	for i = 1, maxindex do
		args[1 + offset][i] = m_links.full_link{ lang = lang, term = args[1 + offset][i], alt = args["alt"][i], tr = args["tr"][i] }
		if args["q"][i] then
			args[1 + offset][i] = args[1 + offset][i] .. " " .. m_qual.format_qualifier({args["q"][i]})
		end
	end
	
	local text = "<span class=\"homophones\">[[Appendix:Glossary#homophone|Homophone" .. (maxindex > 1 and "s" or "") ..
		 "]]: " .. table.concat(args[1 + offset], ", ") .. "</span>"
	local category = "[[Category:" ..
		 lang:getCanonicalName() .. " terms with homophones" .. (args["sort"] and "|" .. args["sort"] or "") .. "]]"
	local namespace = mw.title.getCurrentTitle().nsText
	if (namespace == "") then
		return text .. category
	else
		return text
	end
end

return export
