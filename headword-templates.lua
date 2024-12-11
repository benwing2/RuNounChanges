insert = table.insert
local process_params = require("Module:parameters").process

local export = {}

local function get_args(frame)
	local boolean = {type = "boolean"}
	local boolean_list_allow_holes = {type = "boolean", list = true, allow_holes = true}
	local list_allow_holes = {list = true, allow_holes = true}
	return process_params(frame:getParent().args, {
		[1] = {required = true, type = "language", default = "und"},
		["sc"] = {type = "script"},
		["sort"] = true,

		[2] = {required = true, default = "nouns"},
		["sccat"] = boolean,
		["noposcat"] = boolean,
		["nomultiwordcat"] = boolean,
		["nogendercat"] = boolean,
		["nopalindromecat"] = boolean,
		["nolinkhead"] = boolean,
		["autotrinfl"] = boolean,
		["altform"] = boolean, -- EXPERIMENTAL: see [[Wiktionary:Beer parlour/2024/June#Decluttering the altform mess]]
		["cat2"] = true,
		["cat3"] = true,
		["cat4"] = true,
		
		["head"] = list_allow_holes,
		["id"] = true,
		["tr"] = list_allow_holes,
		["ts"] = list_allow_holes,
		["gloss"] = true,
		["g"] = {list = true},
		["g\1qual"] = list_allow_holes,
		
		[3] = list_allow_holes,
		
		["f\1accel-form"] = list_allow_holes,
		["f\1accel-translit"] = list_allow_holes,
		["f\1accel-lemma"] = list_allow_holes,
		["f\1accel-lemma-translit"] = list_allow_holes,
		["f\1accel-gender"] = list_allow_holes,
		["f\1accel-nostore"] = boolean_list_allow_holes,
		["f\1request"] = list_allow_holes,
		["f\1alt"] = list_allow_holes,
		["f\1lang"] = {list = true, allow_holes = true, type = "language"},
		["f\1sc"] = {list = true, allow_holes = true, type = "script"},
		["f\1id"] = list_allow_holes,
		["f\1tr"] = list_allow_holes,
		["f\1ts"] = list_allow_holes,
		["f\1g"] = list_allow_holes,
		["f\1qual"] = list_allow_holes,
		["f\1autotr"] = boolean_list_allow_holes,
		["f\1nolink"] = boolean_list_allow_holes,
	})
end

function export.head_t(frame)
	local m_headword = require("Module:headword")
	
	local function track(page)
		require("Module:debug/track")("headword/templates/" .. page)
		return true
	end

	local args = get_args(frame)

	-- Get language and script information
	local data = {}
	data.lang = args[1]
	data.sc = args["sc"]
	data.sccat = args["sccat"]
	data.sort_key = args["sort"]
	data.heads = args["head"]
	data.id = args["id"]
	data.translits = args["tr"]
	data.transcriptions = args["ts"]
	data.gloss = args["gloss"]
	data.genders = args["g"]
	-- This shouldn't really happen.
	for i = 1,args["head"].maxindex do
		if not args["head"][i] then
			track("head-with-holes")
		end
	end
	for k, v in pairs(args["gqual"]) do
		if k ~= "maxindex" then
			if data.genders[k] then
				data.genders[k] = {spec = data.genders[k], qualifiers = {v}}
			else
				k = k == 1 and "" or tostring(k)
				error(("g%squal= specified without g%s="):format(k, k))
			end
		end
	end

	-- EXPERIMENTAL: see [[Wiktionary:Beer parlour/2024/June#Decluttering the altform mess]]
	data.altform = args["altform"]
		
	-- Part-of-speech category
	local pos_category = args[2]
	data.noposcat = args["noposcat"]
	
	-- Check for headword aliases and then pluralize if the POS term does not have an invariable plural.
	data.pos_category = m_headword.canonicalize_pos(pos_category)

	-- Additional categories.
	data.categories = {}
	data.whole_page_categories = {}
	data.nomultiwordcat = args["nomultiwordcat"]
	data.nogendercat = args["nogendercat"]
	data.nopalindromecat = args["nopalindromecat"]

	if args["cat2"] then
		insert(data.categories, data.lang:getFullName() .. " " .. args["cat2"])
	end

	if args["cat3"] then
		insert(data.categories, data.lang:getFullName() .. " " .. args["cat3"])
	end

	if args["cat4"] then
		insert(data.categories, data.lang:getFullName() .. " " .. args["cat4"])
	end

	-- Headword linking
	data.nolinkhead = args["nolinkhead"]

	-- Inflected forms
	data.inflections = {enable_auto_translit = args["autotrinfl"]}

	for i = 1, math.ceil(args[3].maxindex / 2) do
		local infl_part = {
			label    = args[3][i * 2 - 1],
			accel    = args["faccel-form"][i] and {
				form      = args["faccel-form"][i],
				translit  = args["faccel-translit"][i],
				lemma     = args["faccel-lemma"][i],
				lemma_translit = args["faccel-lemma-translit"][i],
				gender    = args["faccel-gender"][i],
				nostore   = args["faccel-nostore"][i],
			} or nil,
			request  = args["frequest"][i],
			enable_auto_translit = args["fautotr"][i],
		}
		
		local form = {
			term          =  args[3][i * 2],
			alt           =  args["falt"][i],
			genders       =  args["fg"][i] and mw.text.split(args["fg"][i], ",") or {},
			id            =  args["fid"][i],
			lang          =  args["flang"][i],
			nolinkinfl    =  args["fnolink"][i],
			q             = {args["fqual"][i]},
			sc            =  args["fsc"][i],
			translit      =  args["ftr"][i],
			transcription =  args["fts"][i],
		}
		
		-- If no term or alt is given, then the label is shown alone.
		if form.term or form.alt then
			insert(infl_part, form)
		end
		
		if infl_part.label == "or" then
			-- Append to the previous inflection part, if one exists
			if #infl_part > 0 and data.inflections[1] then
				insert(data.inflections[#data.inflections], form)
			end
		elseif infl_part.label then
			-- Add a new inflection part
			insert(data.inflections, infl_part)
		end
	end
	
	return m_headword.full_headword(data)
end

return export
