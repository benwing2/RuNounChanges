local export = {}

local links_module = "Module:links"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"

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
  ** `qualifiers`: {nil} or a list of left regular qualifier strings; for compatibility purposes only, do not use in new
     code;
  ** `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
     [[Module:accent qualifier]];
  ** `aa`: {nil} or a list of right accent qualifier strings;
  ** `refs`: {nil} or a list of references or reference specs to add after the pronunciation and any posttext and
     qualifiers; the value of a list item is either a string containing the reference text (typically a call to a
	 citation template such as {{tl|cite-book}}, or a template wrapping such a call), or an object with fields `text`
	 (the reference text), `name` (the name of the reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}}
	 or {{cd|<nowiki><ref name="foo" /></nowiki>}}) and/or `group` (the group of the reference, as in
	 {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
	 {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
	 appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
	 {{cd|<nowiki><references /></nowiki>}} section;
  ** `sc`: {nil} or script object for this particular hyphenation/syllabification;
* `sc`: {nil} or script object for the hyphenations/syllabifications;
* `q`: {nil} or a list of overall left regular qualifier strings, formatted using {format_qualifier()} in
  [[Module:qualifier]];
* `qq`: {nil} or a list of overall right regular qualifier strings;
* `a`: {nil} or a list of overall left accent qualifier strings, formatted using {format_qualifiers()} in
  [[Module:accent qualifier]];
* `aa`: {nil} or a list of overall right accent qualifier strings;
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
		local text = require(links_module).full_link {
			lang = data.lang, sc = hyph.sc or data.sc, alt = table.concat(hyph.hyph, "‧"), tr = "-" }
		if hyph.q and hyph.q[1] or hyph.qq and hyph.qq[1] or hyph.qualifiers and hyph.qualifiers[1]
			or hyph.a and hyph.a[1] or hyph.aa and hyph.aa[1] or hyph.refs and hyph.refs[1] then
			text = require(pron_qualifier_module).format_qualifiers {
				lang = data.lang,
				text = text,
				q = hyph.q,
				qq = hyph.qq,
				qualifiers = hyph.qualifiers,
				a = hyph.a,
				aa = hyph.aa,
				refs = hyph.refs,
			}
		end
		table.insert(hyphtexts, text)
	end
	
	local text = (data.nocaption and "") or ((data.caption or "Hyphenation") .. ": ") .. table.concat(hyphtexts, ", ")
	if data.q and data.q[1] or data.qq and data.qq[1] or data.a and data.a[1] or data.aa and data.aa[1] then
		text = require(pron_qualifier_module).format_qualifiers {
			lang = data.lang,
			text = text,
			q = data.q,
			qq = data.qq,
			a = data.a,
			aa = data.aa,
		}
	return text
end


--[==[
Entry point for {{tl|hyphenation}} template (also written {{tl|hyph}}).
]==]
function export.hyphenation(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local lang_param = compat and "lang" or 1
	local offset = compat and 0 or 1
	local params = {
		[lang_param] = {required = true, type = "language", etym_lang = true, default = "und"},
		[1 + offset] = {list = true, required = true, allow_holes = true, default = "{{{2}}}"},
		-- FIXME: For compatibility, q= and qq= refer to the first hyphenation rather than overall. Consider tracking and
		-- changing this.
		["q"] = {list = true, allow_holes = true, type = "qualifier"},
		["qq"] = {list = true, allow_holes = true, type = "qualifier"},
		["a"] = {list = true, allow_holes = true, separate_no_index = true, type = "labels"},
		["aa"] = {list = true, allow_holes = true, separate_no_index = true, type = "labels"},
		["ref"] = {list = true, allow_holes = true, type = "references"},
		["caption"] = {},
		["nocaption"] = {type = "boolean"},
		["sc"] = {list = true, allow_holes = true, separate_no_index = true, type = "script"},
	}
	local args = require(parameters_module).process(parent_args, params)

	local lang = args[lang_param]
	local sc = args.sc.default

	local data = {
		lang = lang,
		sc = sc,
		hyphs = {},
		caption = args.caption,
		nocaption = args.nocaption,
		a = args.a.default,
		aa = args.aa.default,
	}
	local this_hyph = {hyph = {}}
	local maxindex = args[1 + offset].maxindex
	local function insert_hyph()
		local hyphnum = #data.hyphs + 1
		this_hyph.q = args.q[hyphnum]
		this_hyph.qq = args.qq[hyphnum]
		this_hyph.a = args.a[hyphnum]
		this_hyph.aa = args.aa[hyphnum]
		this_hyph.refs = args.ref[hyphnum]
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


return export
