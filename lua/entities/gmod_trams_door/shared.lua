ENT.Type            = "anim"

ENT.PrintName       = "Subway Train Door"
ENT.Author          = ""
ENT.Contact         = ""
ENT.Purpose         = ""
ENT.Instructions    = ""
ENT.Category		= "Drivable Trams"

ENT.AutomaticFrameAdvance = true 

ENT.Spawnable       = false
ENT.AdminSpawnable  = false

function ENT:Think()
	self:NextThink(CurTime())
	
	if SERVER and (!self.LastCheck or self.LastCheck <= CurTime()) then
		self.LastCheck = CurTime() + 1
		if self:GetParent() then
			local tram = self:GetParent()
			if tram.SkinToColor and (!self.LastSkin or self.LastSkin != tram:GetSkin()) then
				
				self.LastSkin = tram:GetSkin()
				
				if tram.SkinToColor[self.LastSkin] then
					self:SetColor(tram.SkinToColor[tram:GetSkin()])
				end
				
			end
			if tram.SkinToSkin and (!self.LastSkin2 or self.LastSkin2 != tram:GetSkin()) then
				self.LastSkin2 = tram:GetSkin()
				
				if tram.SkinToSkin[self.LastSkin2] then
					self:SetSkin(tram.SkinToSkin[tram:GetSkin()])
				end
			end
		end
	end
	
	return true
end

function ENT:SetupDataTables()

	self:NetworkVar( "Vector", 0, "DoorSize" )

end