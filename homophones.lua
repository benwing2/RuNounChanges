local export = {}

local m_links = require("Module:links")

--[=[
Meant to be called from a module. `data` is a table containing the following fields:

{
  lang = LANGUAGE_OBJECT,
  homophones = {{term = "HOMOPHONE", alt = nil or "DISPLAY_TEXT", gloss = nil or "GLOSS", tr = nil or "TRANSLITERATION",
				 pos = nil or "PART_OF_SPEECH", qualifiers = nil or {"QUALIFIER", "QUALIFIER", ...}}, ...},
  sc = nil or SCRIPT_OBJECT,
  sort = nil or "SORTKEY",
  caption = nil or "CAPTION",
  nocaption = BOOLEAN,
}

Here:

* `lang` is a language object.
* `homophones` is the list of homophones to display. HOMOPHONE is a homophone. QUALIFIER is a qualifier string to
  display after the specific homophone in question, formatted using format_qualifier() in [[Module:qualifier]].
  (FIXME: This should be changed to display the qualifier before the homophone.)
* `sc`, if specified, is a script object.
* `sort`, if specified, is a sort key.
* `caption`, if specified, overrides the default caption "Homophone"/"Homophones". A colon and space is automatically
  added after the caption.
* `nocaption`, if specified, suppresses the caption entirely.
]=]
function export.format_homophones(data)
	local hmptexts = {}
	local hmpcats = {}

	for _, hmp in ipairs(data.homophones) do
		hmp.lang = data.lang
		hmp.sc = data.sc
		local text = m_links.full_link(hmp)
		if hmp.qualifiers and hmp.qualifiers[1] then
			text = text .. " " .. require("Module:qualifier").format_qualifier(hmp.qualifiers)
		end
		table.insert(hmptexts, text)
	end

	table.insert(hmpcats, data.lang:getCanonicalName() .. " terms with homophones")
	local text = table.concat(hmptexts, ", ")
	local caption = data.nocaption and "" or (
		data.caption or "[[Appendix:Glossary#homophone|Homophone" .. (#data.homophones > 1 and "s" or "") .. "]]"
	) .. ": "
	text = "<span class=\"homophones\">" .. caption .. text .. "</span>"
	local categories = require("Module:utilities").format_categories(hmpcats, data.lang, data.sort)
	return text .. categories
end


-- Entry point for {{homophones}} template (also written {{homophone}} and {{hmp}}).
function export.show(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, default = "en"},
		[1 + offset] = {list = true, required = true, allow_holes = true, default = "term"},
		["alt"] = {list = true, allow_holes = true},
		["pos"] = {list = true, allow_holes = true},
		["t"] = {list = true, allow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["q"] = {list = true, allow_holes = true},
		["caption"] = {},
		["nocaption"] = {type = "boolean"},
		["sc"] = {},
		["sort"] = {},
	}

	local args = require("Module:parameters").process(parent_args, params)
	
	local lang = require("Module:languages").getByCode(args[compat and "lang" or 1], compat and "lang" or 1)
	local sc = args["sc"] and require("Module:scripts").getByCode(args["sc"], "sc") or nil

	local maxindex = math.max(
		args[1 + offset].maxindex,
		args["alt"].maxindex,
		args["pos"].maxindex,
		args["t"].maxindex,
		args["tr"].maxindex
	)

	local data = {
		lang = lang,
		homophones = {},
		caption = args.caption,
		nocaption = args.nocaption,
		sc = sc,
		sort = args.sort,
	}

	for i = 1, maxindex do
		table.insert(data.homophones, {
			term = args[1 + offset][i],
			alt = args["alt"][i],
			pos = args["pos"][i],
			gloss = args["t"][i],
			tr = args["tr"][i],
			qualifiers = args["q"][i] and {args["q"][i]} or nil,
		})
	end

	return export.format_homophones(data)
end

return export
