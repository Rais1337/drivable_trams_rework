AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	//self:SetDoorSize(Vector(1,1,1))
	/*if ents.FindByClass("gmod_trams_tatra_t3") then
	self:SetSubMaterial(0,"models/drivtrams/other/doors-t6b5su")
	else
	print("net")
	end*/
end
