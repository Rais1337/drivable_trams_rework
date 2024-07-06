include("shared.lua")
net.Receive("metrostroi-train",function()
	local self =  net.ReadEntity()
	local TYPE = net.ReadBit() + 1
	if not self._NetData or not self._NetData[TYPE] then return end
	self._NetData[TYPE][net.ReadInt(16)] = net["Read"..(TYPE == 2 and "Float" or "Type")](TYPE)
end)
net.Receive("metrostroi-train-sync",function()
	local self =  net.ReadEntity()
	self._NetData = net.ReadTable()
end)
--------------------------------------------------------------------------------
-- Decoration props
--------------------------------------------------------------------------------
ENT.ClientProps = {}
--------------------------------------------------------------------------------
-- Clientside entities support
--------------------------------------------------------------------------------
local lastButton
local drawCrosshair
local toolTipText
local lastAimButtonChange
local lastAimButton

function ENT:ShouldRenderClientEnts()
	return true --self:LocalToWorld(Vector(0,0,0)):Distance(LocalPlayer():GetPos()) < 960*2
end

function ENT:CreateCSEnts()
	for k,v in pairs(self.ClientProps) do
		if k ~= "BaseClass" then
			local cent = ClientsideModel(v.model ,RENDERGROUP_OPAQUE)
			cent:SetPos(self:LocalToWorld(v.pos))
			cent:SetAngles(self:LocalToWorldAngles(v.ang))
			cent:SetParent(self)
			self.ClientEnts[k] = cent
		end
	end
end

function ENT:RemoveCSEnts()
	for k,v in pairs(self.ClientEnts) do
		v:Remove()
	end
	self.ClientEnts = {}
end

function ENT:ApplyCSEntRenderMode(render)
	for k,v in pairs(self.ClientEnts) do
		if render then
			v:SetRenderMode(RENDERMODE_NORMAL)
		else
			v:SetRenderMode(RENDERMODE_NONE)
		end
	end
end



--------------------------------------------------------------------------------
-- Clientside initialization
--------------------------------------------------------------------------------
function ENT:Initialize()
	-- Create clientside props
	self.ClientEnts = {}
	self.RenderClientEnts = self:ShouldRenderClientEnts()
	if self.RenderClientEnts then
		self:CreateCSEnts()
	end

	-- Systems defined in the train
	self.Systems = {}
	-- Initialize train systems
	self:InitializeSystems()
	
	-- Create sounds
	self:InitializeSounds()
	self.Sounds = {}
	--self:EntIndex()
	--self.PixVis = util.GetPixelVisibleHandle()
end

function ENT:OnRemove()
	self:RemoveCSEnts()
	drawCrosshair = false
	toolTipText = nil
	
	for k,v in pairs(self.Sounds) do
		v:Stop()
	end
end

--------------------------------------------------------------------------------
-- Default think function
--------------------------------------------------------------------------------
function ENT:Think()
	self.PrevTime = self.PrevTime or RealTime()
	self.DeltaTime = (RealTime() - self.PrevTime)
	self.PrevTime = RealTime()

	-- Simulate systems
	if self.Systems then
		for k,v in pairs(self.Systems) do
			v:ClientThink(self.DeltaTime)
		end
	end
	
	-- Reset CSEnts
	if CurTime() - (self.ClientEntsResetTimer or 0) > 10.0 then
		self.ClientEntsResetTimer = CurTime()
		self:RemoveCSEnts()
		self:CreateCSEnts()
	end
	
	-- Update CSEnts
	if CurTime() - (self.PrevThinkTime or 0) > .5 then
		self.PrevThinkTime = CurTime()
		
		-- Invalidate entities if needed, for hotloading purposes
		if not self.ClientPropsInitialized then
			self.ClientPropsInitialized = true
			self:RemoveCSEnts()
			self.RenderClientEnts = false
		end
		
		local shouldrender = self:ShouldRenderClientEnts()
		if self.RenderClientEnts ~= shouldrender then
			self.RenderClientEnts = shouldrender
			if self.RenderClientEnts then
				self:CreateCSEnts()
			else
				self:RemoveCSEnts()
			end
		end
	end
	
	if self.LightTableInner and self:GetNWBool("LightsOn") then
		for k,v in pairs(self.LightTableInner) do
			local col = v.Col or Color(255,255,255,255)
			local dlight = DynamicLight(self:EntIndex()..k)
			if dlight then
				dlight.pos = (self:LocalToWorld(v.Pos))
				dlight.r = col.r
				dlight.g = col.g
				dlight.b = col.b
				dlight.decay = 1000
				dlight.brightness = v.bright or 2
				dlight.size = v.size or 256
				dlight.dietime = CurTime() + 1
			end
		end
	end
	
end

--------------------------------------------------------------------------------
-- Various rendering shortcuts for trains
--------------------------------------------------------------------------------
function ENT:DrawCircle(cx,cy,radius)
	local step = 2*math.pi/12
	local vertexBuffer = { {}, {}, {} }

	for i=1,12 do
		vertexBuffer[1].x = cx + radius*math.sin(step*(i+0))
		vertexBuffer[1].y = cy + radius*math.cos(step*(i+0))
		vertexBuffer[2].x = cx
		vertexBuffer[2].y = cy
		vertexBuffer[3].x = cx + radius*math.sin(step*(i+1))
		vertexBuffer[3].y = cy + radius*math.cos(step*(i+1))
		surface.DrawPoly(vertexBuffer)
	end
end

--------------------------------------------------------------------------------
-- Default rendering function
--------------------------------------------------------------------------------
function ENT:Draw()
	self.dT = RealTime() - (self.PrevTime2 or RealTime())
	self.PrevTime2 = RealTime()

	-- Draw model
	self:DrawModel()
	
	if self.Systems then
		for k,v in pairs(self.Systems) do
			v:ClientDraw()
		end
	end
end

function ENT:DrawOnPanel(index,func)
	local panel = self.ButtonMap[index]
	cam.Start3D2D(self:LocalToWorld(panel.pos),self:LocalToWorldAngles(panel.ang),panel.scale)
		func(panel)
	cam.End3D2D()
end

--------------------------------------------------------------------------------
-- Animation function
--------------------------------------------------------------------------------
function ENT:Animate(clientProp, value, min, max, speed, damping, stickyness)
	local id = clientProp
	if not self["_anim_"..id] then
		self["_anim_"..id] = value
		self["_anim_"..id.."V"] = 0.0
	end
	
	-- Generate sticky value
	if stickyness and damping then
		self["_anim_"..id.."_stuck"] = self["_anim_"..id.."_stuck"] or false
		self["_anim_"..id.."P"] = self["_anim_"..id.."P"] or value
		if (math.abs(self["_anim_"..id.."P"] - value) < stickyness) and (self["_anim_"..id.."_stuck"]) then
			value = self["_anim_"..id.."P"]
			self["_anim_"..id.."_stuck"] = false
		else
			self["_anim_"..id.."P"] = value
		end
	end
		
	if damping == false then
		local dX = speed * self.DeltaTime
		if value > self["_anim_"..id] then
			self["_anim_"..id] = self["_anim_"..id] + dX
		end
		if value < self["_anim_"..id] then
			self["_anim_"..id] = self["_anim_"..id] - dX
		end
		if math.abs(value - self["_anim_"..id]) < dX then
			self["_anim_"..id] = value
		end
	else
		-- Prepare speed limiting
		local delta = math.abs(value - self["_anim_"..id])
		local max_speed = 1.5*delta / self.DeltaTime
		local max_accel = 0.5 / self.DeltaTime

		-- Simulate
		local dX2dT = (speed or 128)*(value - self["_anim_"..id]) - self["_anim_"..id.."V"] * (damping or 8.0)
		if dX2dT >  max_accel then dX2dT =  max_accel end
		if dX2dT < -max_accel then dX2dT = -max_accel end
		
		self["_anim_"..id.."V"] = self["_anim_"..id.."V"] + dX2dT * self.DeltaTime
		if self["_anim_"..id.."V"] >  max_speed then self["_anim_"..id.."V"] =  max_speed end
		if self["_anim_"..id.."V"] < -max_speed then self["_anim_"..id.."V"] = -max_speed end
		
		self["_anim_"..id] = math.max(0,math.min(1,self["_anim_"..id] + self["_anim_"..id.."V"] * self.DeltaTime))
		
		-- Check if value got stuck
		if (math.abs(dX2dT) < 0.001) and stickyness and (self.DeltaTime > 0) then
			self["_anim_"..id.."_stuck"] = true
		end
	end

	if self.ClientEnts[clientProp] then
		self.ClientEnts[clientProp]:SetPoseParameter("position",min + (max-min)*self["_anim_"..id])
	end
	return min + (max-min)*self["_anim_"..id]
end

function ENT:ShowHide(clientProp, value)
	if self.ClientEnts[clientProp] then
		if value == true then
			self.ClientEnts[clientProp]:SetRenderMode(RENDERMODE_NORMAL)
			self.ClientEnts[clientProp]:SetColor(Color(255,255,255,255))
		else
			self.ClientEnts[clientProp]:SetRenderMode(RENDERMODE_NONE)
			self.ClientEnts[clientProp]:SetColor(Color(0,0,0,0))
		end		
	end
end

local digit_bitmap = {
  [1] = { 0,0,1,0,0,1,0 },
  [2] = { 1,0,1,1,1,0,1 },
  [3] = { 1,0,1,1,0,1,1 },
  [4] = { 0,1,1,1,0,1,0 },
  [5] = { 1,1,0,1,0,1,1 },
  [6] = { 1,1,0,1,1,1,1 },
  [7] = { 1,0,1,0,0,1,0 },
  [8] = { 1,1,1,1,1,1,1 },
  [9] = { 1,1,1,1,0,1,1 },
  [0] = { 1,1,1,0,1,1,1 },
}

local segment_poly = {
	[1] = { 	
		{ x = 0,    y = 0 },
		{ x = 100,  y = 0 },
		{ x =  80,  y = 20 },
		{ x =  20,  y = 20 },
	},
	[2] = { 	
		{ x =  20,  y = 0 },
		{ x =  80,  y = 0 },
		{ x = 100,  y = 20 },
		{ x =   0,  y = 20 },
	},
	[3] = { 	
		{ x =  0,  y = 0 },
		{ x = 20,  y = 20 },
		{ x = 20,  y = 80 },
		{ x =  0,  y = 100 },
	},
	[4] = { 	
		{ x =  0,  y = 20 },
		{ x = 20,  y = 0 },
		{ x = 20,  y = 100 },
		{ x =  0,  y = 80 },
	},
	[5] = { 	
		{ x = 0,  y = 12 },
		{ x = 20,  y = 0 },
		{ x = 80,  y = 0 },
		{ x = 100,  y = 12 },
		{ x = 80,  y = 24 },
		{ x = 20,  y = 24 },
	},
}

function ENT:DrawSegment(i,x,y,scale_x,scale_y)
	local poly = {}
	for k,v in pairs(segment_poly[i]) do
		poly[k] = {
			x = (v.x*scale_x) + x,
			y = (v.y*scale_y) + y,		
		}
	end
	
	surface.SetDrawColor(Color(100,255,0,255))
	draw.NoTexture()
	surface.DrawPoly(poly)
end

function ENT:DrawDigit(cx,cy,digit,scalex,scaley,thickness)
	scalex = scalex or 1
	scaley = scaley or scalex
	thickness = thickness or 1
	local bitmap = digit_bitmap[digit]
	if not bitmap then return end

	local sx = 0.9*scalex*thickness
	local sy = 0.9*scaley*thickness
	local dx = scalex
	local dy = scaley
	
	if bitmap[1] == 1 then self:DrawSegment(1,cx+5*dx,cy,			sx,sy)	end
	if bitmap[2] == 1 then self:DrawSegment(3,cx,cy+10*dy,			sx,sy)	end
	if bitmap[3] == 1 then self:DrawSegment(4,cx+80*dx,cy+10*dy,	sx,sy)	end
	if bitmap[4] == 1 then self:DrawSegment(5,cx+5*dx,cy+95*dy,		sx,sy)	end
	if bitmap[5] == 1 then self:DrawSegment(3,cx,cy+110*dy,			sx,sy)	end
	if bitmap[6] == 1 then self:DrawSegment(4,cx+80*dx,cy+110*dy,	sx,sy)	end
	if bitmap[7] == 1 then self:DrawSegment(2,cx+5*dx,cy+190*dy,	sx,sy)	end
end



--------------------------------------------------------------------------------
-- Get train acceleration at given position in train
--------------------------------------------------------------------------------
function ENT:GetTrainAccelerationAtPos(pos)
	local localAcceleration = self:GetTrainAcceleration()
	local angularVelocity = self:GetTrainAngularVelocity()
	
	return localAcceleration - angularVelocity:Cross(angularVelocity:Cross(pos*0.01905))
end

local matLight = Material("trams/glow")
local matBeam = Material( "effects/flashlight/hard" )

function ENT:DrawTranslucent()
	//BaseClass.DrawTranslucent( self )
	-- No glow if we're not switched on!
	if ( !self:GetNWBool("LightsOn") ) then return end
	if self.LightTables then
		if !self.PixelVisiblesLights then
			self.PixelVisiblesLights = {}
		end
		for k,v in pairs(self.LightTables) do
		
			local LightNrm = (self:GetAngles()+v.Ang):Forward()
			local ViewNormal = (self:LocalToWorld(v.Pos)) - EyePos()
			local Distance = ViewNormal:Length()
			ViewNormal:Normalize()
			local ViewDot = ViewNormal:Dot( LightNrm * -1 )
			local LightPos = (self:LocalToWorld(v.Pos)) + LightNrm*5

			if ( ViewDot >= 0 ) then

				render.SetMaterial( matLight )
				if !self.PixelVisiblesLights[k] then self.PixelVisiblesLights[k] = util.GetPixelVisibleHandle() end
				local Visibile = util.PixelVisible( LightPos, 16, self.PixelVisiblesLights[k] )

				if ( !Visibile or Visibile <= 0 ) then return end
	
				local Size = math.Clamp( Distance * Visibile * ViewDot * 2, 64, 512 )

				Distance = math.Clamp( Distance, 64, 800 )
				local Alpha = math.Clamp( ( 1000 - Distance ) * Visibile * ViewDot, 0, 100 )
				local Col = self:GetColor()
				Col.a = Alpha

				render.DrawSprite( LightPos, Size, Size, Col, Visibile * ViewDot )
				render.DrawSprite( LightPos, Size * 0.4, Size * 0.4, Color( 255, 255, 255, Alpha ), Visibile * ViewDot )
				
				render.DrawSprite( LightPos, 70, 70, Color(255,255,255,100), Visibile )
				render.DrawSprite( LightPos, 50, 50, Color(255,255,255,200), Visibile )
	
			end
		end
	end
	if self.LightTableInner then
		if !self.PixelVisiblesLightsInner then
			self.PixelVisiblesLightsInner = {}
		end
		for k,v in pairs(self.LightTableInner) do
			
			//local LightNrm = (self:GetAngles()+v.Ang):Forward()
			local ViewNormal = (self:LocalToWorld(v.Pos)) - EyePos()
			local Distance = ViewNormal:Length()
			ViewNormal:Normalize()
			//local ViewDot = ViewNormal:Dot( LightNrm * -1 )
			local LightPos = (self:LocalToWorld(v.Pos))
			
			local col = v.Col or Color(255,255,255,255)


				render.SetMaterial( matLight )
				if !self.PixelVisiblesLightsInner[k] then self.PixelVisiblesLightsInner[k] = util.GetPixelVisibleHandle() end
				local Visibile = util.PixelVisible( LightPos, 16, self.PixelVisiblesLightsInner[k] )

				if ( !Visibile or Visibile <= 0 ) then return end
	
				local Size = math.Clamp( Distance * Visibile , 64, 512 )

				Distance = math.Clamp( Distance, 64, 800 )
				local Alpha = math.Clamp( ( 1000 - Distance ) * Visibile * 0.5, 0, 100 )
				local Col = col//self:GetColor()
				Col.a = Alpha

				render.DrawSprite( LightPos, Size, Size, Col, Visibile )
				render.DrawSprite( LightPos, Size * 0.4, Size * 0.4, Color( 255, 255, 255, Alpha ), Visibile )
				
				render.DrawSprite( LightPos, 70, 70, col, Visibile )
				render.DrawSprite( LightPos, 50, 50, col, Visibile )
	
		end
	end
end

surface.CreateFont("TramSpeedometer", {
	font = "Time",
	extended = false,
	size = 35,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = true,
	additive = false,
	outline = true,
})

local ControllerToText = {
[-4] = "Т4",
[-3] = "Т3",
[-2] = "Т2",
[-1] = "Т1",
[0] = "0",
[1] = "Х1",
[2] = "Х2",
[3] = "Х3",
[4] = "Х4",
}

hook.Add("HUDPaint", "DrawSpeedometerTram", function()
	local shoulddraw = hook.Call("HUDShouldDraw", GAMEMODE, "TramSpeedometer")
	if shoulddraw then
		local seat = LocalPlayer():GetVehicle()
		if IsValid(seat) then
			local tram = seat:GetNWEntity("TrainEntity")
			if IsValid(tram) then
				local text = "0 KM/H"
				local vel = tram:GetVelocity():Length()
				local speed = math.Round(vel * 0.09144)
				text = speed.." KM/H"
				if speed >= 55 then
					draw.SimpleText(text, "TramSpeedometer", ScrW()/2+300, ScrH()-40, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
				if speed < 55 then
					draw.SimpleText(text, "TramSpeedometer", ScrW()/2+300, ScrH()-40, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
				if tram.ControllerPowered then
					local text2 = tram:GetNWInt("Controller", 0)
					local sas = tram:GetNWBool("ToggleReverse", false)	
					local sas2 = ""
					if sas then sas2 = "R" end
					local text3 = "POS:"..ControllerToText[text2].." "..sas2
					draw.SimpleTextOutlined(text3, "DermaLarge", ScrW()/2+50, ScrH()-40, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
							
				end
			end
		end
	end
end)


