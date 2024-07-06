ENT.Type            = "anim"
ENT.Base            = "gmod_trams_base"

ENT.PrintName       = "Tatra T6B5SU"
ENT.Author          = ""
ENT.Contact         = ""
ENT.Purpose         = ""
ENT.Instructions    = ""
ENT.Category		= "Drivable Trams Rework"
ENT.ControllerPowered = true

ENT.Spawnable       = true
ENT.AdminSpawnable  = false


function ENT:InitializeSystems()
	self:LoadSystem("T6B5_Systems")
end

ENT.LightTables = {
	[1] = {
		Pos = Vector(326.6, 36.2, -40),
		Ang = Angle(0, 0, 0),
	},
	[2] = {
		Pos = Vector(326.6, -35, -40),
		Ang = Angle(0, 0, 0),
	},
}

ENT.LightTableInner = {
	[1] = {
	Pos = Vector(300, 10.5, 50),
	size = 200,
	Col = Color(157,163,161),
	bright = 4
	},
	[2] = {
	Pos = Vector(210, 10.5, 50),
	size = 200,
	Col = Color(255,190,50),
	bright = 4
	},
	[3] = {
	Pos = Vector(27, 10.5, 50),
	size = 200,
	Col = Color(255,190,50),
	bright = 4
	},
	[4] = {
	Pos = Vector(-170, 10, 50),
	size = 250,
	Col = Color(255,190,50),
	bright = 4
	},
}