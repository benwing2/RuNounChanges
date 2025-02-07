local export = {}

local etymology_module = "Module:etymology"

local rsplit = mw.text.split


local function parse_args(args)
	local boolean = {type = "boolean"}
	local list_allow_holes = {list = true, allow_holes = true}
	args = require("Module:parameters").process(args, {
		[1] = {required = true, type = "language", default = "und"},
		[2] = list_allow_holes,
		["t"] = list_allow_holes,
		["gloss"] = {list = true, allow_holes = true, alias_of = "t"},
		["tr"] = list_allow_holes,
		["ts"] = list_allow_holes,
		["g"] = list_allow_holes,
		["id"] = list_allow_holes,
		["alt"] = list_allow_holes,
		["q"] = list_allow_holes,
		["qq"] = list_allow_holes,
		["lit"] = list_allow_holes,
		["pos"] = list_allow_holes,
		-- Note, lang1=, lang2=, ... are different from 1=; the former apply to
		-- individual arguments, while the latter applies to all arguments
		["lang"] = {type = "language", list = true, allow_holes = true, require_index = true},
		["sc"] = {type = "script"},
		-- Note, sc1=, sc2=, ... are different from sc=; the former apply to
		-- individual arguments when lang1=, lang2=, ... is specified, while
		-- the latter applies to all arguments where langN=... isn't specified
		["partsc"] = {type = "script", list = "sc", allow_holes = true, require_index = true},
		["noast"] = boolean,
		["and"] = boolean,
		["compare"] = boolean,
		["notes"] = true,
	})
	return args, args[1], args["sc"]
end


local function get_parsed_part(args, i)
	local term_index = 2
	local term = args[term_index][i]
	local alt = args["alt"][i]
	local id = args["id"][i]
	local lang = args["lang"][i]
	local sc = args["partsc"][i]
	
	local tr = args["tr"][i]
	local ts = args["ts"][i]
	local gloss = args["t"][i]
	local pos = args["pos"][i]
	local lit = args["lit"][i]
	local q = args["q"][i]
	local qq = args["qq"][i]
	local g = args["g"][i]

	if not (term or alt or tr or ts) then
		require("Module:debug").track("see/no term or alt or tr")
		return nil
	else
		local termlang, actual_term
		if term then
			termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
			if termlang then
				termlang = require("Module:languages").getByCode(termlang, nil, "allow etym") or nil
			end
			if not termlang then -- If not a valid language code, treat it as part of the term.
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
	for _, v in pairs(args) do
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
	for _, part in ipairs(parts) do
		local result
		if part.q then
			result = require("Module:qualifier").format_qualifier(part.q) .. " "
		else
			result = ""
		end
		part.sc = part.sc or sc
		if part.lang then
			result = result .. require(etymology_module).format_derived{
				terminfo = part,
				nocat = true,
				template_name = "see",
			}
		else
			part.lang = lang
			result = result .. require("Module:links").full_link(part, nil, false)
		end

		if part.qq then
			result = result .. " " .. require("Module:qualifier").format_qualifier(part.qq)
		end

		table.insert(termparts, result)
	end

	if #termparts == 1 then
		ins(termparts[1])
	else
		ins(require("Module:table").serialCommaJoin(termparts, {conj = "''and''"}))
	end

	if args.notes then
		ins(" ''")
		ins(args.notes)
		ins("''")
	end

	return table.concat(textparts)
end


return export
