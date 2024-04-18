local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("bcl")
local PAGENAME = mw.title.getCurrentTitle().text
local script = lang:findBestScript(PAGENAME) -- Latn or Tglg

local function track(page)
	require("Module:debug/track")("bcl-headword/" .. page)
	return true
end

function export.show(frame)
	local tracking_categories = {}

	local args = frame:getParent().args
	local poscat = frame.args[1] or require("Module:string utilities").pluralize(args["pos"]) or error("Part of speech has not been specified. Please pass parameter to the module invocation.")

	local head = {} -- supports multiple headword
	local function insert_head(arg)
		if arg == "" then
			track("blank-head")
			arg = PAGENAME
		end
		if arg then
			table.insert(head, arg)
		end
	end
	insert_head(args["head"] or args[1])
	insert_head(args["head2"] or args[2])
	insert_head(args["head3"] or args[3])

	local data = {lang = lang, sc = script, pos_category = poscat, categories = {}, heads = head, tr = tr, inflections = {}}
	
	local basahan = {label = "Basahan spelling"}
	local sc_Tglg = require("Module:scripts").getByCode("Tglg")
	if args["b"] then table.insert(basahan, { term = args["b"], sc = sc_Tglg }) end
	if args["b2"] then table.insert(basahan, { term = args["b2"], sc = sc_Tglg }) end
	if args["b3"] then table.insert(basahan, { term = args["b3"], sc = sc_Tglg }) end
	if script:getCode() == "Latn" then
		if #basahan > 0 then 
			table.insert(data.inflections, basahan) 
			table.insert(data.categories, "Bikol Central terms with Baybayin script")
		else
			table.insert(data.categories, "Bikol Central terms without Baybayin script")
		end
	elseif script:getCode() == "Tglg" then
		--Categorize words with Basahan
        table.insert(data.categories, "Bikol Central terms in Baybayin script")
    end

	-- Basahan to Latin
	local tr = args["tr"]
	if not tr then
		tr = require("Module:bcl-translit")
	end
	
	-- feminines and masculines
	local fem = {label = "feminine"}
	if args["f"] then table.insert(fem, {term = args["f"]}) end
	if #fem > 0 then table.insert(data.inflections, fem) end
	
	local masc = {label = "masculine"}	
	if args["m"] then table.insert(masc, {term = args["m"]}) end
	if #masc > 0 then table.insert(data.inflections, masc) end
	
	local plural = {label = "plural", accel = {form = "plural"} }	
	if args["plural"] then table.insert(plural, {term = args["plural"]}) end
	if #plural > 0 then table.insert(data.inflections, plural) end
	
	local collective = {label = "collective" }	
	if args["collective"] then table.insert(collective, {term = args["collective"]}) end
	if #collective > 0 then table.insert(data.inflections, collective) end

	if pos_functions[poscat] then
		pos_functions[poscat](args, data)
	end

	local content = mw.title.new(PAGENAME):getContent()
	local code = content and mw.ustring.match(content, "{{bcl%-IPA[^}]*}}")

    --Categorize words without [[Template:bcl-IPA]]
	if script:getCode() == "Latn" and not code then
		table.insert(tracking_categories, "Bikol Central terms without bcl-IPA template")
	end

	return require("Module:headword").full_headword(data) .. require("Module:utilities").format_categories(tracking_categories, lang)

end

pos_functions["verbs"] = function(args, data)

    params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'comp'},
		[3] = {alias_of = 'prog'},
		[4] = {alias_of = 'cont'},
		head = {list = true},
		head2= {},
		head3= {},
		comp = {list = true},
		prog = {list = true},
		cont = {list = true},
		rootword = {},
		b= {},
		b2= {},
		b3= {},
		tr= {}
	}

	local args = require("Module:parameters").process(args,params)
	data.heads = args.head
	data.id = args.id
	local pattern = args.pattern
	
	args.comp.label = "complete"
	args.prog.label = "progressive"
	args.cont.label = "contemplative"

	args.comp.accel = {form = "comp"}
	args.prog.accel = {form = "prog"}
	args.cont.accel = {form = "cont"}

	if #args.comp > 0 then table.insert(data.inflections, args.comp) end
	if #args.prog > 0 then table.insert(data.inflections, args.prog) end
	if #args.cont > 0 then table.insert(data.inflections, args.cont) end

    --Tagging root forms of verbs
	local rootword = args["rootword"] or nil
	if require("Module:yesno")(rootword) then 
		table.insert(data.inflections, {label = "root word"}) 
		table.insert(data.categories, "Bikol Central roots")
	end

    --Tagging verb trigger
    local conjtype = args["type"] or nil
    if conjtype and conjugation_types[conjtype] then
		table.insert(data.inflections, {label = conjugation_types[conjtype][1]})
		table.insert(data.categories, conjugation_types[conjtype][2])
    end
    
        local conjtype = args["type2"] or nil
    if conjtype and conjugation_types[conjtype] then
		table.insert(data.inflections, {label = conjugation_types[conjtype][1]})
		table.insert(data.categories, conjugation_types[conjtype][2])
	end	
		
		    local conjtype = args["type3"] or nil
    if conjtype and conjugation_types[conjtype] then
		table.insert(data.inflections, {label = conjugation_types[conjtype][1]})
		table.insert(data.categories, conjugation_types[conjtype][2])
    end

end

pos_functions["nouns"] = function(args, data)

	--Tagging root forms of nouns
	local rootword = args["rootword"] or nil 
	if require("Module:yesno")(rootword) then 
		table.insert(data.inflections, {label = "root word"}) 
		table.insert(data.categories, "Bikol Central roots")
	end

end

return export
