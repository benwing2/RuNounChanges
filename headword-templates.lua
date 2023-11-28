local export = {}

function export.head_t(frame)
	local function track(page)
		require("Module:debug/track")("headword/templates/" .. page)
		return true
	end

	local args = require("Module:parameters").process(frame:getParent().args, mw.loadData("Module:parameters/data")["headword/templates"].head_t, nil, "headword/templates", "head_t")
	
	-- Get language and script information
	local data = {}
	data.lang = require("Module:languages").getByCode(args[1], 1, "allow etym")
	data.sort_key = args["sort"]
	data.heads = args["head"]
	data.id = args["id"]
	data.translits = args["tr"]
	data.transcriptions = args["ts"]
	data.gloss = args["gloss"]
	data.genders = args["g"]
	-- This shouldn't really happen.
	for i=1,args["head"].maxindex do
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

	-- Script
	data.sc = args["sc"] and require("Module:scripts").getByCode(args["sc"], "sc") or nil
	data.sccat = args["sccat"]

	-- Part-of-speech category
	data.pos_category = args[2]
	data.noposcat = args["noposcat"]

	local headword_data = mw.loadData("Module:headword/data")

	-- Check for headword aliases and then pluralize if the POS term does not have an invariable plural.
	data.pos_category = headword_data.pos_aliases[data.pos_category] or data.pos_category
	if not data.pos_category:find("s$") and not headword_data.invariable[data.pos_category] then
		-- Make the plural form of the part of speech
		data.pos_category = data.pos_category:gsub("x$", "%0e") .. "s"
	end
	
	-- Additional categories.
	data.categories = {}
	data.whole_page_categories = {}
	data.nomultiwordcat = args["nomultiwordcat"]
	data.nogendercat = args["nogendercat"]
	data.nopalindromecat = args["nopalindromecat"]
	
	if args["cat2"] then
		table.insert(data.categories, data.lang:getNonEtymologicalName() .. " " .. args["cat2"])
	end
	
	if args["cat3"] then
		table.insert(data.categories, data.lang:getNonEtymologicalName() .. " " .. args["cat3"])
	end
	
	if args["cat4"] then
		table.insert(data.categories, data.lang:getNonEtymologicalName() .. " " .. args["cat4"])
	end
	
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
			nolink        =  args["fnolink"][i],
			q             = {args["fqual"][i]},
			sc            =  args["fsc"][i],
			translit      =  args["ftr"][i],
			transcription =  args["fts"][i],
		}
		
		if form.lang then
			form.lang = require("Module:languages").getByCode(form.lang, "f" .. i .. "lang", "allow etym")
		end
		
		if form.sc then
			form.sc = require("Module:scripts").getByCode(form.sc, "f" .. i .. "sc")
		end
		
		-- If no term or alt is given, then the label is shown alone.
		if form.term or form.alt then
			table.insert(infl_part, form)
		end
		
		if infl_part.label == "or" then
			-- Append to the previous inflection part, if one exists
			if #infl_part > 0 and data.inflections[1] then
				table.insert(data.inflections[#data.inflections], form)
			end
		elseif infl_part.label then
			-- Add a new inflection part
			table.insert(data.inflections, infl_part)
		end
	end
	
	return require("Module:headword").full_headword(data)
end

return export
