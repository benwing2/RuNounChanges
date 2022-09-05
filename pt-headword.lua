local m_adj = require("Module:pt-adjectives")
local m_conj = require("Module:pt-conj")

local lang = require("Module:languages").getByCode("pt")

local export = {}
local pos_functions = {}

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = frame:getParent().args
	PAGENAME = mw.title.getCurrentTitle().text
	
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {}, genders = {}, inflections = {}}
	
	-- Call POS-specific function
	if pos_functions[poscat] then
		pos_functions[poscat](args, data)
	end
	
	if args["head"] then
		data.heads = { args["head"] }
	end
	
	if #data.heads == 0 then
		data.heads = { "" }
	end
	
	return require("Module:headword").full_headword(data)
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = function(args, data)
	local base = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}")
	local infl_type = args[2] or (mw.title.getCurrentTitle().nsText == "Template" and "o") or ""
	
	if base == "-" then
		table.insert(data.inflections, {label = "[[Appendix:Glossary#invariable|invariable]]"})
	elseif infl_type == "" then
		local f_sg = {args["f"]}
		local m_pl = {args["mpl"] or args["pl"]}
		local f_pl = {args["fpl"]}
		
		if #f_sg > 0 then
			f_sg.label = "feminine singular"
			f_sg.accel = {form = "f|s"}
			table.insert(data.inflections, f_sg)
		end
		
		if #f_pl == 0 or m_pl[1] == f_pl[1] then
			m_pl.label = "plural"
			m_pl.accel = {form = "p"}
			table.insert(data.inflections, m_pl)
		else
			m_pl.label = "masculine plural"
			m_pl.accel = {form = "m|p"}
			table.insert(data.inflections, m_pl)
			
			f_pl.label = "feminine plural"
			f_pl.accel = {form = "f|p"}
			table.insert(data.inflections, f_pl)
		end
	else
		if not m_adj.inflections[infl_type] then
			error("Unknown inflection type '" .. infl_type .. "'")
		end
		
		if not base then error("Parameter 1 (base stem) may not be empty.") end
		local infldata = {forms = {}, title = nil, categories = {}}
		m_adj.inflections[infl_type](args, base, infldata)
		
		if infldata.forms["m_sg"][1] == infldata.forms["f_sg"][1] then
			table.insert(data.genders, "m")
			table.insert(data.genders, "f")
		else
			table.insert(data.genders, "m")
			
			local f_sg = infldata.forms["f_sg"]
			f_sg.label = "feminine singular"
			f_sg.accel = {form = "f|s"}
			table.insert(data.inflections, f_sg)
		end
		
		if infldata.forms["m_pl"][1] == infldata.forms["f_pl"][1] then
			local pl = infldata.forms["m_pl"]
			pl.label = "plural"
			pl.accel = {form = "p"}
			table.insert(data.inflections, pl) 
		else
			local m_pl = infldata.forms["m_pl"]
			m_pl.label = "masculine plural"
			m_pl.accel = {form = "m|p"}
			table.insert(data.inflections, m_pl)
			
			local f_pl = infldata.forms["f_pl"]
			f_pl.label = "feminine plural"
			f_pl.accel = {form = "f|p"}
			table.insert(data.inflections, f_pl)
		end
		
		if plural and not mw.title.new(plural).exists then
			table.insert(data.categories, "Portuguese nouns with missing plurals")
		end
		
		if plural2 and not mw.title.new(plural2).exists then
			table.insert(data.categories, "Portuguese nouns with missing plurals")
		end
	end
	
	local comp = args["comp"]
	
	if comp == "no" then
		table.insert(data.inflections, {label = "not [[Appendix:Glossary#comparable|comparable]]"})
		table.insert(data.categories, lang:getCanonicalName() .. " uncomparable adjectives")
	elseif comp == "both" then
		table.insert(data.inflections, {label = "sometimes [[Appendix:Glossary#comparable|comparable]]"})
		table.insert(data.categories, lang:getCanonicalName() .. " uncomparable adjectives")
	else
		table.insert(data.inflections, {label = "[[Appendix:Glossary#comparable|comparable]]"})
	end
end

-- comparatives and superlatives
pos_functions["comparative adjectives"] = pos_functions["adjectives"]
pos_functions["superlative adjectives"] = pos_functions["adjectives"]

local function addVerbInflections(verb, inflections)
	local first_pres_sing = verb.forms.indi.pres.sing['1']
	if first_pres_sing and #first_pres_sing > 0 then
		table.insert(inflections, { label = "first-person singular present indicative", first_pres_sing })
	end
	if verb.forms.part_past then
		table.insert(inflections, { label = "past participle", verb.forms.part_past.sing.m })
	end
	if verb.forms.short_part_past then
		table.insert(inflections, { label = "short past participle", verb.forms.short_part_past.sing.m })
	end
	if verb.forms.long_part_past then
		table.insert(inflections, { label = "long past participle", verb.forms.long_part_past.sing.m })
	end
end

local function addVerbCategories(verb, categories)
	if verb.abundant then table.insert(categories, lang:getCanonicalName()  .. " abundant verbs") end
	if verb.defective then table.insert(categories, lang:getCanonicalName() .. " defective verbs") end
	if verb.irregular then table.insert(categories, lang:getCanonicalName() .. " irregular verbs") end
	if verb.forms.short_part_past and verb.forms.long_part_past then
		table.insert(categories, lang:getCanonicalName() .. " verbs with short and long past participle")
	end
end

pos_functions["verbs"] = function(args, data)
	local beginning = args[1] or ""
	local ending    = args[2] or ""
	local compound  = args[3]

	local verb = m_conj.inflect(beginning, ending, compound)

	if verb then
		table.insert(data.heads, verb.forms.infn.impe)
		addVerbCategories(verb, data.categories)
		addVerbInflections(verb, data.inflections)
	else
		table.insert(data.categories, "Requests for inflections in " .. lang:getCanonicalName() .. " verb entries")
	end
end


return export
