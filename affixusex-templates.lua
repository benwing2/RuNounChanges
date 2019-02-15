local export = {}

local rfind = mw.ustring.find

function export.affixusex_t(frame)
	local params = {
		[1] = {required = true},
		[2] = {list = true, allow_holes = true},
		
		["t"] = {list = true, allow_holes = true},
		["gloss"] = {alias_of = "t"},
		["tr"] = {list = true, allow_holes = true},
		["ts"] = {list = true, allow_holes = true},
		["g"] = {list = true, allow_holes = true},
		["id"] = {list = true, allow_holes = true},
		["altaff"] = {},
		["alt"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["lit"] = {list = true, allow_holes = true},
		["pos"] = {list = true, allow_holes = true},
		["sc"] = {},
		["noaffix"] = {type = "boolean"},
		["arrow"] = {list = true, allow_holes = true, type = "boolean"},
		["accel"] = {list = true, allow_holes = true},
	}

	local aftype = frame.args["type"]
	if aftype == "" or not aftype then
		aftype = "affix"
	end

	if aftype == "prefix" then
		params["altpref"] = {alias_of = "altaff"}
	elseif aftype == "suffix" then
		params["altsuf"] = {alias_of = "altaff"}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[1]
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, 1)
	local sc = args["sc"]
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(params) do
		if v.list and v.allow_holes and args[k].maxindex > maxmaxindex then
			maxmaxindex = args[k].maxindex
		end
	end

	-- Determine whether the terms in the numbered params contain an affix. If not, we will
	-- insert one before the last term, unless noaffix= is true.
	local parts = {}
	local affix_in_parts = false
	for i=1,maxmaxindex do
		if part.term then
			if (aftype == "prefix" or aftype == "affix") and rfind(part.term, "%-$") then
				affix_in_parts = true
			end
			if (aftype == "suffix" or aftype == "affix") and rfind(part.term, "^%-") then
				affix_in_parts = true
			end
		end
	end

	-- Build up the per-term objects.
	for i=1,maxmaxindex do
		-- If we're about to append the last term, and no affix appeared among the terms, and
		-- noaffix= isn't set, insert the affix (which comes either from altaff=/altpref=/altsuf=
		-- or from the subpage name).
		if i == maxmaxindex and not args["noaffix"] and not affix_in_parts then
			local affix = args["altaff"]
			affix = affix or mw.title.getCurrentTitle().subpageText
			table.insert(parts, {alt = affix})
		end

		local part = {}
		part.term = args[2][i]
		part.t = args["t"][i]
		part.tr = args["tr"][i]
		part.ts = args["ts"][i]
		part.g = args["g"][i]
		part.id = args["id"][i]
		part.alt = args["alt"][i]
		part.q = args["q"][i]
		part.lit = args["lit"][i]
		part.pos = args["pos"][i]
		part.arrow = args["arrow"][i]
		part.accel = args["accel"][i] and string.gsub(args["accel"], "_", "|"),  -- To allow use of | in templates
		table.insert(parts, part)
	end

	return require("Module:affixusex").format_affixusex(lang, sc, parts, aftype)
end

return export
