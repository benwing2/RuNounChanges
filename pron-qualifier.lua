local export = {}

local accent_qualifier_module = "Module:accent qualifier"
local parse_utilities_module = "Module:parse utilities"
local qualifier_module = "Module:qualifier"
local references_module = "Module:references"
local string_utilities_module = "Module:string utilities"

local function rsplit(text, pattern)
	return require(string_utilities_module).split(text, pattern)
end

local function track(page)
	require("Module:debug/track")("pron qualifier/" .. page)
	return true
end

local function split_on_comma(term)
	if not term then
		return nil
	end
	if term:find(",%s") then
		return require(parse_utilities_module).split_on_comma(term)
	elseif term:find(",") then
		return rsplit(term, ",")
	else
		return {term}
	end
end

--[==[
Parse left and right regular and accent qualifiers and references, for pronunciation or related modules that want to
provide support for these.

`data` is a structure containing the following fields:
* `obj`: The object to write the parsed qualifiers and references into.
* `q`: Left regular qualifier.
* `qq`: Right regular qualifiers.
* `qualifiers`: Regular qualifiers (left or right), for compatibility.
* `a`: List of comma-separated left accent qualifiers.
* `aa`: List of right accent qualifiers, each a string.
* `refs: Spec for one or more references; see the documentation of [[Module:IPA]].
]==]
function export.parse_qualifiers(data)
	local obj = data.store_obj
	obj.refs = data.refs and require(references_module).parse_references(data.refs) or nil
	obj.q = data.q and {data.q} or nil
	obj.qq = data.qq and {data.qq} or nil
	obj.qualifiers = data.qualifiers and {data.qualifiers} or nil
	obj.a = split_on_comma(data.a)
	obj.aa = split_on_comma(data.aa)
end

--[==[
This function is used by any module that wants to add support for left and right regular and accent qualifiers to a
template that specifies a pronunciation or related property. It is currently used by [[Module:rhymes]],
[[Module:hyphenation]], [[Module:homophones]] and [[Module:es-pronunc]] (for specifying pronunciation, rhymes,
hyphenation, homophones and audio in {{tl|es-pr}}). It should potentially also be used in {{tl|audio}}. To reduce memory
usage, the caller should check that any qualifiers exist before loading the module.

`data` is a structure containing the following fields:
* `q`: List of left regular qualifiers, each a string.
* `qq`: List of right regular qualifiers, each a string.
* `qualifiers`: List of qualifiers, each a string, for compatibility. If `qualifiers_right` is given, these are
   right qualifiers, otherwise left qualifiers. If both `qualifiers` and `q`/`qq` (depending on the value of
   `qualifiers_right`) are non-{nil}, `qualifiers` is ignored.
* `a`: List of left accent qualifiers, each a string.
* `aa`: List of right accent qualifiers, each a string.
* `refs`: {nil} or a list of references or reference specs to add directly after the text; the value of a list item
  is either a string containing the reference text (typically a call to a citation template such as {{tl|cite-book}}, or
  a template wrapping such a call), or an object with fields `text` (the reference text), `name` (the name of the
  reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}} or {{cd|<nowiki><ref name="foo" /></nowiki>}})
  and/or `group` (the group of the reference, as in {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
  {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
  appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
  {{cd|<nowiki><references /></nowiki>}} section.
* `lang`: Language object for accent qualifiers.
* `text`: The text to wrap with qualifiers.
* `qualifiers_right`: If specified, qualifiers in `qualifiers` are placed to the right, otherwise the left. See above.

Accent qualifiers precede (are to the left of) regular qualifiers, both on the left and right sides.
]==]
function export.format_qualifiers(data)
	if not data.text then
		error("Missing `data.text`; did you try to pass `text` or `qualifiers_right` as separate params?")
	end
	if not data.lang then
		track("nolang")
	end
	local text = data.text
	local function format_q(q)
		return require(qualifier_module).format_qualifier(q)
	end
	local function format_a(a)
		return require(accent_qualifier_module).format_qualifiers(data.lang, a)
	end
	if data.refs then
		text = text .. require(references_module).format_references(data.refs)
	end
	-- This order puts the accent qualifiers before other qualifiers on both the left and the right. (FIXME: are we
	-- sure about this?)
	local leftq = data.q or not data.qualifiers_right and data.qualifiers
	if leftq and leftq[1] then
		text = format_q(leftq) .. " " .. text
	end
	local lefta = data.a
	if lefta and lefta[1] then
		text = format_a(lefta) .. " " .. text
	end
	local righta = data.aa
	if righta and righta[1] then
		text = text .. " " .. format_a(righta)
	end
	local rightq = data.qq or data.qualifiers_right and data.qualifiers
	if rightq and rightq[1] then
		text = text .. " " .. format_q(rightq)
	end
	return text
end

return export
