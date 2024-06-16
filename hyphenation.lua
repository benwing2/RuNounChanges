local export = {}

local function track(page)
	require("Module:debug/track")("hyphenation/" .. page)
	return true
end

--[==[
Meant to be called from a module. `data` is a table containing the following fields:
* `lang`: language object for the hyphenations or syllabifications;
* `hyphs`: a list of hyphenations/syllabifications, each described by an object which can contain the following fields:
  ** `hyph`: list of syllables comprising the hyphenation or syllabification, each a string;
  ** `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in
     [[Module:qualifier]];
  ** `qq`: {nil} or a list of right regular qualifier strings;
  ** `qualifiers`: {nil} or a list of left regular qualifier strings; for compatibiliy purposes only, do not use in new
     code;
  ** `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
     [[Module:accent qualifier]];
  ** `aa`: {nil} or a list of right accent qualifier strings;
* `sc`: {nil} or script object for the hyphenations/syllabifications;
* `caption`, {nil} or a string specifying the caption to use, in place of {"Hyphenation"}; e.g. use {"Syllabification"}
  if what is passed in is actually a syllabification, as is common; a colon and space is automatically added after the
  caption;
* `nocaption`: if true, suppress the caption display.
]==]
function export.format_hyphenations(data)
	local hyphtexts = {}

	for _, hyph in ipairs(data.hyphs) do
		if #hyph.hyph == 0 then
			error("Saw empty hyphenation; use || to separate hyphenations")
		end
		local text = require("Module:links").full_link {
			lang = data.lang, sc = data.sc, alt = table.concat(hyph.hyph, "‧"), tr = "-" }
		if hyph.q and hyph.q[1] or hyph.qq and hyph.qq[1] or hyph.qualifiers and hyph.qualifiers[1]
			or hyph.a and hyph.a[1] or hyph.aa and hyph.aa[1] then
			text = require("Module:pron qualifier").format_qualifiers {
				lang = data.lang,
				text = text,
				q = hyph.q,
				qq = hyph.qq,
				qualifiers = hyph.qualifiers,
				a = hyph.a,
				aa = hyph.aa,
			}
		end
		table.insert(hyphtexts, text)
	end
	
	local prefix = (data.nocaption and "") or ((data.caption or "Hyphenation") .. ": ")
	local text = table.concat(hyphtexts, ", ")
	return prefix .. text
end


--[==[
The implementation of the {{tl|hyphenation}} template. Broken out so that it can function as an (older) entry point
for modules. '''FIXME''': Convert modules that use this to use {format_hyphenations()} directly.
]==]
function export.hyphenate(parent_args, notrack)
	if not notrack then
		track("hyphenate-entry-point")
	end
	local compat = parent_args["lang"]
	local offset = compat and 0 or 1
	local params = {
		[compat and "lang" or 1] = {required = true, default = "und"},
		[1 + offset] = {list = true, required = true, allow_holes = true, default = "{{{2}}}"},
		["q"] = {list = true, allow_holes = true},
		["caption"] = {},
		["nocaption"] = {type = "boolean"},
		["sc"] = {},
	}
	local args = require("Module:parameters").process(parent_args, params)
	
	local lang = require("Module:languages").getByCode(args[compat and "lang" or 1], compat and "lang" or 1)
	local sc = args["sc"] and require("Module:scripts").getByCode(args["sc"], "sc") or nil

	local data = {
		lang = lang,
		sc = sc,
		hyphs = {},
		caption = args.caption,
		nocaption = args.nocaption,
	}
	local this_hyph = {hyph = {}}
	local maxindex = args[1 + offset].maxindex
	local function insert_hyph()
		local hyphnum = #data.hyphs + 1
		if args["q"][hyphnum] then
			this_hyph.qualifiers = {args["q"][hyphnum]}
		end
		table.insert(data.hyphs, this_hyph)
	end
	for i=1, maxindex do
		local syl = args[1 + offset][i]
		if not syl then
			insert_hyph()
			this_hyph = {hyph = {}}
		else
			table.insert(this_hyph.hyph, syl)
		end
	end
	insert_hyph()

	return export.format_hyphenations(data)
end


--[==[
Entry point for {{tl|hyphenation}} template (also written {{tl|hyph}}).
]==]
function export.hyphenation(frame)
	local parent_args = frame:getParent().args
	return export.hyphenate(parent_args)
end


return export
