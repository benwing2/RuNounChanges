local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end


local function make_try(word)
	return function(from, to)
		local stem, extra_capture = rmatch(word, "^(.*)" .. from .. "$")
		if extra_capture then
			return stem .. extra_capture .. to
		end
		if stem then
			return stem .. to
		end
		return nil
	end
end


function export.soften_masc_pers_pl(word)
	local try = make_try(word)
	return
		try("ch", "si") or
		try("h", "si") or
		try("zł", "źli") or
		try("sł", "śli") or
		try("ł", "li") or
		try("rz?", "rzy") or
		try("sn", "śni") or
		try("zn", "źni") or
		try("st", "ści") or
		try("t", "ci") or
		try("d", "dzi") or
		try("sz", "si") or
		try("([cd]z)", "y") or
		try("([fwmpbnsz])", "i") or
		try("stk", "scy") or -- [[wszystek]] -> 'wszysci'
		try("k", "cy") or
		try("g", "dzy") or
		word .. "y"
end


return export
