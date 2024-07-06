AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_vehicles/trams/tatra_t3/tatra_join.mdl");
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType( MOVETYPE_VPHYSICS);
	self:SetSolid(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	
	local pObject = self:GetPhysicsObject();
	
	if (IsValid( pObject )) then
		pObject:Wake();
	end;
	
end

function ENT:Touch( ent )
	if self.Train and IsValid(self.Train) then
		if ent:GetClass() == "gmod_trams_coupler" and !self.Coupled and !ent.Coupled and self.Rev and self.Rev != ent.Rev then
			self:Couple( ent )
		end
	end
end
local limit = 3
function ENT:Couple( ent )
	if !self.Coupled and ent.Train:GetClass() == self.Train:GetClass() and (!self.LastCouple or self.LastCouple <= CurTime()) and (!ent.LastCouple or ent.LastCouple <= CurTime()) then
		local count1 = 1
		local count2 = 1
		if ent.Train.CoupledTrains then
			count1 = #ent.Train.CoupledTrains
		end
		if self.Train.CoupledTrains then
			count2 = #self.Train.CoupledTrains
		end
		if count1 + count2 <= 3 then
			local connection = constraint.AdvBallsocket(
				self,
				ent,
				0, --bone
				0, --bone
				Vector(40,0,0),
				Vector(40,0,0),
				0, --forcelimit
				0, --torquelimit
				-180, --xmin
				-180, --ymin
				-180, --zmin
				180, --xmax
				180, --ymax
				180, --zmax
				0, --xfric
				0, --yfric
				0, --zfric
				0, --rotonly
				1 --nocollide
			)
			if IsValid(connection) then
				self.LastCouple = CurTime() + 3
				ent.LastCouple = CurTime() + 3
				self.Coupled = ent
				ent.Coupled = self
				self.Connection = connection
				ent.Connection = connection
				sound.Play("buttons/lever2.wav",(self:GetPos()+ent:GetPos())/2)
				
				if ent.Train.CoupledTrains then
				
					if self.Rev then
						if self.Train.CoupledTrains then
							local tabl = self.Train.CoupledTrains
							local start = #tabl+1
							for k,v in pairs(ent.Train.CoupledTrains) do
								tabl[start] = v
								start = start+1
							end
							for k,v in pairs(tabl) do
								v.CoupledTrains = tabl
							end
						else
							table.insert(ent.Train.CoupledTrains, 1, self.Train)
							self.Train.CoupledTrains = ent.Train.CoupledTrains
						end
					/*else
						if self.Train.CoupledTrains then
							local tabl = ent.Train.CoupledTrains
							local start = #tabl+1
							for k,v in pairs(self.Train.CoupledTrains) do
								tabl[start] = v
								start = start+1
							end
							for k,v in pairs(tabl) do
								v.CoupledTrains = tabl
							end
						else
							table.insert(ent.Train.CoupledTrains, #ent.Train.CoupledTrains+1, self.Train)
							self.Train.CoupledTrains = ent.Train.CoupledTrains
						end*/
					end
					
				else
				
					local tabl = {}
					if self.Rev then
						if self.Train.CoupledTrains then
							tabl = self.Train.CoupledTrains
							table.insert(tabl, #self.Train.CoupledTrains+1, ent.Train)
						else
							tabl = {
								[1] = self.Train,
								[2] = ent.Train
							}
						end
						
					/*else
						tabl = {
							[1] = ent.Train,
							[2] = self.Train
						}*/
					end
					for k,v in pairs(tabl) do
						v.CoupledTrains = tabl
					end
				end
			end
		end
	end
end

function ENT:DeCouple()
	if self.Coupled and IsValid(self.Coupled) and (!self.LastCouple or self.LastCouple <= CurTime()) and (!self.Coupled.LastCouple or self.Coupled.LastCouple <= CurTime()) then
		local ent = self.Coupled
		
		
		if self.Rev then
			ent.LastCouple = CurTime() + 3
			self.LastCouple = CurTime() + 3
			ent.Coupled = nil
			self.Coupled = nil
			
			if IsValid(self.Connection) then
				SafeRemoveEntity(self.Connection)
			end
			/*if IsValid(self.Connection2) then
				SafeRemoveEntity(self.Connection2)
			end*/
			sound.Play("buttons/lever2.wav",(self:GetPos()+ent:GetPos())/2)
			
			local trainnum = table.KeyFromValue(self.Train.CoupledTrains, self.Train)
			
			local count = #self.Train.CoupledTrains
			
			if trainnum == 1 then
				if count > 2 then
					local tabl = self.Train.CoupledTrains
					local start = 1
					local newtabl = {}
					for k,v in pairs(tabl) do
						if k != 1 then
							newtabl[start] = v
							start = start + 1
						end
					end
					self.Train.CoupledTrains = nil
					for k,v in pairs(newtabl) do
						v.CoupledTrains = newtabl
					end
				else
					self.Train.CoupledTrains = nil
					ent.Train.CoupledTrains = nil
				end
			else
				local tabl = self.Train.CoupledTrains
				local start = 1
				local start2 = 1
				local newtabl = {}
				local newtabl2 = {}
				for k,v in pairs(tabl) do
					if k <= trainnum then
						newtabl[start] = v
						start = start + 1
					else
						newtabl2[start2] = v
						start2 = start2 + 1
					end
				end
				if #newtabl > 1 then
					for k,v in pairs(newtabl) do
						v.CoupledTrains = newtabl
					end
				else
					newtabl[1].CoupledTrains = nil
				end
				if #newtabl2 > 1 then
					for k,v in pairs(newtabl2) do
						v.CoupledTrains = newtabl2
					end
				else
					newtabl2[1].CoupledTrains = nil
				end
			end
			
		else
			ent:DeCouple()
			
		end
		
	end
end

function ENT:OnRemove()
	self:DeCouple()
end

function ENT:Use()
	if self.Coupled and IsValid(self.Coupled) then
		self:DeCouple(self.Coupled)
	end
end