local LuaVersion,OUTER = _VERSION,_G
local setmetatable,assert,loadstring,setfenv,error,type,tostring = setmetatable,assert,loadstring,setfenv,error,type,tostring
local tableConcat = table.concat
local ioOpen = io.open

module("luahtml")

local function bracketfinder(text, bracket)
	local bracket = bracket or "["
	bracket = bracket:gsub("%[", "%%["):gsub("%]", "%%]")
	local out,pos,count = {},0,0
	while true do
		pos = text:find(bracket:rep(2), pos)
		if pos then
			count = count+1
			out[count] = pos
			pos = pos + 1
		else
			break
		end
	end
	return out
end

local function tsort(t)
	local out,i = {},1
	for n=1,#t do
		local item = t[n]
		if item then
			out[i] = item
			i = i + 1
		end
	end
	return out
end

local function blockfinder(text)
	local ops,eds,out = bracketfinder(text,"["),bracketfinder(text,"]"),{}
	if #ops ~= #eds then
		return nil,"Malformed LuaHTML page"
	end
	while true do
		local stop = false
		for n=1,#ops do
			local op,nop,ed = ops[n],(ops[n+1] or nil),eds[n]
			if nop and nop < ed and nop > op then
				ops[n+1] = nil
				ops = tsort(ops)
				eds[n] = nil
				eds = tsort(eds)
				break
			else
				stop = true
			end
		end
		if stop then
			break
		end
	end
	return ops,eds
end

function format(text)
	if not text or type(text) ~= "string" then
		error("bad argument #1 to 'format' (string expected, got "..type(text)..")")
	end
	if not text:find("%[%[") then
		return text
	end
	local env,blocks,out,p = {},{},{},{}
	setmetatable(env, {__index = OUTER})
	if LuaVersion == "Lua 5.1" then
		function env.print(...)
			local t = {...}
			for n=1,#t do
				p[#p+1] = tostring(t[n]).."\n"
			end
		end
	end
	local ops,eds = blockfinder(text)
	if not ops then return nil,eds end
	for n=1,#ops do
		local block = text:sub(ops[n]+2,eds[n]-1)
		if block:sub(1,1) == "=" then
			block = "return "..block:sub(2)
		end
		local result,p = nil,{}
		if LuaVersion == "Lua 5.1" then
			local blockf = assert(loadstring(block))
			setfenv(blockf, env)
			result = blockf()
		elseif LuaVersion == "Lua 5.2" then
		-- this doesn't work. :(
			local outer = _ENV
			local function print(...)
				local t = {...}
				for n=1,#t do
					p[#p+1] = outer.tostring(t[n]).."\n"
				end
			end
			local _ENV = env
			local blockf = assert(loadstring(block))
			result = blockf()
		end
		local st = 1
		if eds[n-1] then
			st = eds[n-1]+2
		end
		out[#out+1] = text:sub(st,ops[n]-1)
		if #p ~= 0 then
			for n=1,#p do
				out[#out+1] = p[n]
			end
			p = {}
		end
		if result then
			out[#out+1] = result
		end
	end
	out[#out+1] = text:sub(eds[#eds]+2)
	return tableConcat(out)
end

function open(file, data)
	local s,err
	if type(file) == "string" then
	-- assume filename
		local fhand,err = ioOpen(file, "r")
		if not fhand then return nil,err end
		s,err = fhand:read("*all")
		fhand:close()
	elseif file.read then
		s,err = file:read("*all")
	else
		return false,"Not a valid file identifier."
	end
	if not s then return nil,err end
	return format(s, data)
end