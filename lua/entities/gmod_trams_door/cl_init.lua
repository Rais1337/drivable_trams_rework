include("shared.lua")

function ENT:Initialize()
	if self:GetDoorSize() and self:GetDoorSize() != Vector(1,1,1) then
		local scale = self:GetDoorSize()

		local mat = Matrix()
		mat:Scale( scale )
		self:EnableMatrix( "RenderMultiply", mat )
	end
end