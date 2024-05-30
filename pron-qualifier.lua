
local export = {}

local function track(page)
	require("Module:debug/track")("pron qualifier/" .. page)
	return true
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
		return require("Module:qualifier").format_qualifier(q)
	end
	local function format_a(a)
		return require("Module:accent qualifier").format_qualifiers(data.lang, a)
	end
	-- This order puts the accent qualifiers before other qualifiers on both the left and the right.
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
