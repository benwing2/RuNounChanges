local export = {}

local m_languages = require("Module:languages")
local m_links = require("Module:links")

local rsplit = mw.text.split


local function fetch_script(sc, param)
	return sc and require("Module:scripts").getByCode(sc, param) or nil
end


local function parse_args(args)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true, allow_holes = true},
		
		["t"] = {list = true, allow_holes = true},
		["gloss"] = {list = true, allow_holes = true, alias_of = "t"},
		["tr"] = {list = true, allow_holes = true},
		["ts"] = {list = true, allow_holes = true},
		["g"] = {list = true, allow_holes = true},
		["id"] = {list = true, allow_holes = true},
		["alt"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["qq"] = {list = true, allow_holes = true},
		["lit"] = {list = true, allow_holes = true},
		["pos"] = {list = true, allow_holes = true},
		-- Note, lang1=, lang2=, ... are different from 1=; the former apply to
		-- individual arguments, while the latter applies to all arguments
		["lang"] = {list = true, allow_holes = true, require_index = true},
		["sc"] = {},
		-- Note, sc1=, sc2=, ... are different from sc=; the former apply to
		-- individual arguments when lang1=, lang2=, ... is specified, while
		-- the latter applies to all arguments where langN=... isn't specified
		["partsc"] = {list = "sc", allow_holes = true, require_index = true},
		["noast"] = {type = "boolean"},
		["and"] = {type = "boolean"},
		["compare"] = {type = "boolean"},
		["notes"] = {},
	}

	args = require("Module:parameters").process(args, params)
	local lang = m_languages.getByCode(args[1], 1)
	return args, lang, fetch_script(args["sc"], "sc")
end


local function get_parsed_part(args, i)
	local term_index = 2
	local term = args[term_index][i]
	local alt = args["alt"][i]
	local id = args["id"][i]
	local lang = args["lang"][i]
	local sc = fetch_script(args["partsc"][i], "sc" .. i)
	
	local tr = args["tr"][i]
	local ts = args["ts"][i]
	local gloss = args["t"][i]
	local pos = args["pos"][i]
	local lit = args["lit"][i]
	local q = args["q"][i]
	local qq = args["qq"][i]
	local g = args["g"][i]

	if lang then
		lang = m_languages.getByCode(lang, "lang" .. i, "allow etym")
	end

	if not (term or alt or tr or ts) then
		require("Module:debug").track("see/no term or alt or tr")
		return nil
	else
		local termlang, actual_term
		if term then
			termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
			if termlang and termlang ~= "w" then -- special handling for w:... links to Wikipedia
				-- -1 since i is one-based
				termlang = m_languages.getByCode(termlang, term_index + i - 1, "allow etym")
			else
				termlang = nil
				actual_term = term
			end
		end
		if lang and termlang then
			error(("Both lang%s= and a language in %s= given; specify one or the other"):format(i, term_index + i - 1))
		end
		return { term = actual_term, alt = alt, id = id, lang = lang or termlang, sc = sc, tr = tr,
			ts = ts, gloss = gloss, pos = pos, lit = lit, q = q, qq = qq,
			genders = g and rsplit(g, ",") or {}
		}
	end
end


local function get_parsed_parts(args)
	local parts = {}

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	for index = 1, maxmaxindex do
		local part = get_parsed_part(args, index)
		parts[index] = part
	end
	
	return parts
end


function export.see(frame)
	local args, lang, sc = parse_args(frame:getParent().args)

	local nocat = args["nocat"]
	local notext = args["notext"]
	local text = not notext and frame.args["text"]
	local oftext = not notext and (frame.args["oftext"] or text and "of")
	local cat = not nocat and frame.args["cat"]

	local parts = get_parsed_parts(args)

	if not next(parts) and mw.title.getCurrentTitle().nsText == "Template" then
		parts = { {term = "term"} }
	end

	local textparts = {}
	local function ins(text)
		table.insert(textparts, text)
	end
	if not args.noast then
		ins("* ")
	end
	ins("''")
	if args["and"] then
		ins("and ")
	end
	if args.compare then
		ins("compare with: ")
	else
		ins("see: ")
	end
	ins("''")

	local termparts = {}
	-- Make links out of all the parts
	for i, part in ipairs(parts) do
		local result
		if part.q then
			result = require("Module:qualifier").format_qualifier(part.q) .. " "
		else
			result = ""
		end
		part.sc = part.sc or sc
		if part.lang then
			result = result .. require("Module:etymology").format_derived(nil, part, nil, true, "see")
		else
			part.lang = lang
			result = result .. m_links.full_link(part, nil, false)
		end

		if part.qq then
			result = result .. " " .. require("Module:qualifier").format_qualifier(part.qq)
		end

		table.insert(termparts, result)
	end

	if #termparts == 1 then
		ins(termparts[1])
	else
		ins(require("Module:table").serialCommaJoin(termparts, {italicizeConj = true}))
	end

	if args.notes then
		ins(" ''")
		ins(args.notes)
		ins("''")
	end

	return table.concat(textparts)
end


return export
