local export = {}

local m_links = require("Module:links")

local function track(page)
	require("Module:debug/track")("homophones/" .. page)
	return true
end

--[==[
Meant to be called from a module. `data` is a table containing the following fields:
* `lang`: language object for the homophones;
* `homophones`: a list of homophones, each described by an object which can contain all the fields in the object
  passed to {full_link()} in [[Module:links]] except for `lang` and `sc` (which are copied from the outer level), and in
  addition can contain left and right regular and accent qualifier fields:
  ** `term`: the homophone itself;
  ** `alt`: display text for the homophone, as in {{tl|l}};
  ** `gloss`: gloss for the homophone, as in {{tl|l}};
  ** `tr`: transliteration for the homophone, as in {{tl|l}};
  ** `ts`: transcription for the homophone, as in {{tl|l}};
  ** `g`: list of genders for the homophone, as in {{tl|l}};
  ** `pos`: part of speech of the homophone, as in {{tl|l}};
  ** `lit`: literal meaning of the homophone, as in {{tl|l}};
  ** `id`: sense ID for the homophone, as in {{tl|l}};
  ** `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in
     [[Module:qualifier]];
  ** `qq`: {nil} or a list of right regular qualifier strings;
  ** `qualifiers`: {nil} or a list of qualifier strings; currently displayed on the right but that may change; for
     compatibiliy purposes only, do not use in new code;
  ** `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
     [[Module:accent qualifier]];
  ** `aa`: {nil} or a list of right accent qualifier strings;
* `sc`: {nil} or script object for the homophones;
* `sort`: {nil} or sort key;
* `caption`: {nil} or string specifying the caption to use, in place of {"Homophone"} (if there is a single homophone),
  or {"Homophones"} (otherwise); a colon and space is automatically added after the caption;
* `nocaption`: If true, suppress the caption display.

'''WARNING''': Destructively modifies the objects inside the `homophones` field.
]==]
function export.format_homophones(data)
	local hmptexts = {}
	local hmpcats = {}

	for _, hmp in ipairs(data.homophones) do
		hmp.lang = data.lang
		hmp.sc = data.sc
		local text = m_links.full_link(hmp)
		if hmp.q and hmp.q[1] or hmp.qq and hmp.qq[1] or hmp.qualifiers and hmp.qualifiers[1]
			or hmp.a and hmp.a[1] or hmp.aa and hmp.aa[1] then
			-- FIXME, change handling of `qualifiers`
			text = require("Module:pron qualifier").format_qualifiers {
				lang = data.lang,
				text = text,
				q = hmp.q,
				qq = hmp.qq,
				qualifiers = hmp.qualifiers,
				a = hmp.a,
				aa = hmp.aa,
				qualifiers_right = true,
			}
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


--[==[
Entry point for {{tl|homophones}} template (also written {{tl|homophone}} and {{tl|hmp}}).
]==]
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
		["qq"] = {list = true, allow_holes = true},
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
			qualifiers = args["q"][i] and track("q") and {args["q"][i]} or nil,
			qq = args["qq"][i] and {args["qq"][i]} or nil,
		})
	end

	return export.format_homophones(data)
end

return export
