local tableSort = table.sort

module("luahtml", package.seeall)

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

function blockfinder(text)
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
	for n=1,#ops do
		local block = text:sub(ops[n]+2,eds[n]-1)
		if block:sub(1,1) == "=" then
			block = "return "..block:sub(2)
		end
		print(block)
	end
end