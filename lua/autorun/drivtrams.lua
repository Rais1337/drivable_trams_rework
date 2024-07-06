--------------------------------------------------------------------------------
-- Add all required clientside files
--------------------------------------------------------------------------------
local function resource_AddDir(dir)
	local files,dirs = file.Find(dir.."/*","GAME")
	for _, fdir in pairs(dirs) do
		resource_AddDir(dir.."/"..fdir)
	end

	for k,v in pairs(files) do
		resource.AddFile(dir.."/"..v)
	end
end




--------------------------------------------------------------------------------
-- Create metrostroi global library
--------------------------------------------------------------------------------
if not Drivtrams then
	-- Global library
	Drivtrams = {}
	
	-- Supported train classes
	Drivtrams.TrainClasses = {}
	Drivtrams.IsTrainClass = {}
	timer.Simple(0.05, function() 
		for name,ent_base in pairs(scripted_ents.GetList()) do
			local prefix = "gmod_trams_"
			if string.sub(name,1,#prefix) == prefix then
				table.insert(Drivtrams.TrainClasses,name)
				Drivtrams.IsTrainClass[name] = true
			end
		end
	end)
	
	-- List of all systems
	Drivtrams.Systems = {}
	Drivtrams.BaseSystems = {}
end


--------------------------------------------------------------------------------
-- Load core files
--------------------------------------------------------------------------------
if SERVER then

	-- Load all serverside lua files
	local files = file.Find("metrostroi/sv_*.lua","LUA")
	for _,filename in pairs(files) do include("metrostroi/"..filename) end
	-- Load all shared files serverside
	local files = file.Find("metrostroi/sh_*.lua","LUA")
	for _,filename in pairs(files) do include("metrostroi/"..filename) end

	-- Add all clientside files
	local files = file.Find("metrostroi/cl_*.lua","LUA")
	for _,filename in pairs(files) do AddCSLuaFile("metrostroi/"..filename) end
	-- Add all shared files
	local files = file.Find("metrostroi/sh_*.lua","LUA")
	for _,filename in pairs(files) do AddCSLuaFile("metrostroi/"..filename) end
	-- Add all system files
	local files = file.Find("metrostroi/systems/sys_*.lua","LUA")
	for _,filename in pairs(files) do AddCSLuaFile("metrostroi/systems/"..filename) end
else
	-- Load all clientside files
	local files = file.Find("metrostroi/cl_*.lua","LUA")
	for _,filename in pairs(files) do include("metrostroi/"..filename) end
	
	-- Load all shared files
	local files = file.Find("metrostroi/sh_*.lua","LUA")
	for _,filename in pairs(files) do include("metrostroi/"..filename) end
end




--------------------------------------------------------------------------------
-- Load systems
--------------------------------------------------------------------------------

function Drivtrams.DefineSystem(name)
	if not Drivtrams.BaseSystems[name] then
		Drivtrams.BaseSystems[name] = {}
	end
	TRAIN_SYSTEM = Drivtrams.BaseSystems[name]
	TRAIN_SYSTEM_NAME = name
end

local function loadSystem(filename)
	-- Get the Lua code
	include(filename)
	
	-- Load train systems
	if TRAIN_SYSTEM then TRAIN_SYSTEM.FileName = filename end
	local name = TRAIN_SYSTEM_NAME or "UndefinedSystem"
	TRAIN_SYSTEM_NAME = nil

	-- Load up the system
	Drivtrams.Systems["_"..name] = TRAIN_SYSTEM
	Drivtrams.BaseSystems[name] = TRAIN_SYSTEM
	Drivtrams.Systems[name] = function(train,...)
		local tbl = { _base = name }
		local TRAIN_SYSTEM = Drivtrams.BaseSystems[tbl._base]
		if not TRAIN_SYSTEM then print("No system: "..tbl._base) return end
		for k,v in pairs(TRAIN_SYSTEM) do
			if type(v) == "function" then
				tbl[k] = function(...) 
					if not Drivtrams.BaseSystems[tbl._base][k] then
						print("ERROR",k,tbl._base)
					end
					return Drivtrams.BaseSystems[tbl._base][k](...) 
				end
			else
				tbl[k] = v
			end
		end
		
		tbl.Initialize = tbl.Initialize or function() end
		tbl.ClientInitialize = tbl.ClientInitialize or function() end
		tbl.Think = tbl.Think or function() end
		tbl.ClientThink = tbl.ClientThink or function() end
		tbl.ClientDraw = tbl.ClientDraw or function() end
		tbl.Inputs = tbl.Inputs or function() return {} end
		tbl.Outputs = tbl.Outputs or function() return {} end
		tbl.TriggerOutput = tbl.TriggerOutput or function() end
		tbl.TriggerInput = tbl.TriggerInput or function() end
		
		tbl.Train = train
		if SERVER then
			tbl:Initialize(...)
		else
			tbl:ClientInitialize(...)
		end
		tbl.OutputsList = tbl:Outputs()
		tbl.InputsList = tbl:Inputs()
		tbl.IsInput = {}
		for k,v in pairs(tbl.InputsList) do tbl.IsInput[v] = true end
		return tbl
	end
end

-- Load all systems
local files = file.Find("metrostroi/systems/sys_*.lua","LUA")
for _,short_filename in pairs(files) do 
	local filename = "metrostroi/systems/"..short_filename
	
	-- Load the file
	if SERVER 
	then loadSystem(filename)
	else timer.Simple(0.05, function() loadSystem(filename) end)
	end
end
