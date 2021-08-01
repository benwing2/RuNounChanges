local ex = {}

local lang = require("Module:languages").getByCode("yi")
local sc = require("Module:scripts").getByCode("Hebr")
local u = mw.ustring

local function ptranslit(text)
	return lang:transliterate(text, sc)
end

function ex.form(text, tr)
	if (not text) then
		if tr then
			return { text = "", tr = tr }
		else
			return nil
		end
	elseif text == "-" then
		return text
	elseif type(text) == "table" then
		if tr then
			return { text = text.text, tr = tr }
		else
			return text
		end
	else
		return { text = text, tr = tr }
	end
end

function ex.translit(f)
	f = ex.form(f)
	return f.tr or ptranslit(f.text)
end

local finals = {
	["ך"] = "כ",
	["ם"] = "מ",
	["ן"] = "נ",
	["ף"] = "פֿ",
	["ץ"] = "צ",
}

local simple_finalizers = {
	["כ"] = "ך",
	["מ"] = "ם",
	["נ"] = "ן",
	["פ"] = "ף",
	["צ"] = "ץ",
}

function ex.finalize(f)
	if (not f) or f == "-" then
		return f
	end
	local tmp = f.text
	tmp = u.gsub(tmp, "[כמנפצ]$", simple_finalizers)
	tmp = u.gsub(tmp, "פֿ$", "ף")
	return ex.form(tmp, f.tr)
end

-- For use by template code, e.g. {{yi-noun}}
function ex.make_non_final(frame_or_term)
	local text = frame_or_term
	if type(text) == "table" then
		text = text.args[1]
	end
	-- Discard second return value.
	local retval = u.gsub(text, "[ךםןףץ]$", finals)
	return retval
end
	
local function append2(f0, f1)
	if not (f0 and f1) then
		return f0 or f1 -- if either is nil return the other
	end
	if f0 == "-" or f1 == "-" then
		return "-" -- if either is a dash, return a dash
	end
	f0 = ex.form(f0); f1 = ex.form(f1) -- just in case
	local text = nil
	if u.match(f1.text, "^[א-ת]") then 
		text = u.gsub(f0.text, "[ךםןףץ]$", finals) .. f1.text
	else
		text = f0.text .. f1.text
	end
	local tr = nil
	if f0.tr or f1.tr then
		tr = ex.translit(f0) .. ex.translit(f1)
	end
	return ex.form(text, tr)
end

function ex.suffix(f0, f1)
	if f0 == "-" or f1 == "-" then
		return "-" -- if either is a dash, return a dash
	end
	f0 = ex.form(f0)
	f1 = ex.form(f1)
	if f0.tr and not f1.tr then
		f1.tr = ptranslit("־" .. f1.text):gsub("^-", "")
	end
	return append2(f0, f1)
end

-- no special handling for prefixes, but function exists for consitency
function ex.prefix(f0, f1)
	return append2(f0, f1)
end

function ex.append(...)
	local f0 = nil
	for i, v in ipairs(arg) do
		f0 = append2(f0, v)
	end
	return f0
end

function ex.ends_nasal(f)
	if f == "-" then
		return false
	end
	f = ex.form(f)
	if f.tr then
		return (u.match(f.tr, "[mn]$") or u.match(f.tr, "n[gk]$")) and true or false
	else
		return (u.match(f.text, "[מםנן]$") or u.match(f.text, "נ[גק]$")) and true or false
	end
end

function ex.ends_vowel(f)
	if f == "-" then
		return false
	else
		return u.match(ex.translit(f), "[aeiouy]$") and true or false
	end
end

local pat = {
	["t"] = "ט",
	["d"] = "ד",
	["s"] = "ס",
	["z"] = "ז",
	["ts"] = "[צץ]",
	["i"] = "%f[וי]י",
	["u"] = "%f[ו]ו",
	["d"] = "ד",
	["e"] = "ע",
	["n"] = "[נן]",
	["m"] = "[מם]",
	["ng"] = "נג",
	["nk"] = "נק",
}

function ex.ends_in(f, x)
	if f == "-" then
		return false
	end
	f = ex.form(f)
	if f.tr then
		return u.match(f.tr, x .. "$") and true or false
	else
		return u.match(f.text, pat[x] .. "$") and true or false
	end
end

return ex
