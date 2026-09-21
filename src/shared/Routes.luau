local Routes = {}
local rng = Random.new()
local V = Vector3.new
local function route(z, bend, turn)
	return {V(-108,1,z), V(bend,1,z), V(bend,1,turn), V(65,1,turn), V(65,1,0), V(108,1,0)}
end
Routes.Layouts = {
	{Name="Twin Rivers", Paths={route(-48,-42,-22),route(48,-16,22)}},
	{Name="Three Fronts", Paths={route(-52,-65,-28),route(0,-30,0),route(52,-5,28)}},
	{Name="Wide Flank", Paths={route(-45,15,-35),route(45,-60,35)}},
}
function Routes.Distance(point,a,b)
	local d=b-a
	if d.Magnitude<0.01 then return (point-a).Magnitude end
	return (point-(a+d*math.clamp((point-a):Dot(d)/d:Dot(d),0,1))).Magnitude
end
function Routes.Length(path, startIndex)
	local length=0
	for i=startIndex or 1,#path-1 do length+=(path[i+1]-path[i]).Magnitude end
	return length
end
function Routes.Score(path,movement,towers,config)
	local score=0
	for _,tower in towers:GetChildren() do
		local data=config.Towers[tower:GetAttribute("TowerType")]
		if data and tower.PrimaryPart and (data.Target=="Both" or data.Target==movement) then
			local range=tower:GetAttribute("Range") or data.Range
			local dps=(tower:GetAttribute("Damage") or data.Damage)/data.Cooldown
			for i=1,#path-1 do
				local length=(path[i+1]-path[i]).Magnitude
				local samples=math.max(1,math.ceil(length/6))
				for j=1,samples do
					local p=path[i]:Lerp(path[i+1],(j-0.5)/samples)
					p=V(p.X,movement=="Air" and 13 or 4,p.Z)
					if (p-(tower.PrimaryPart.Position+V(0,2.7,0))).Magnitude<=range then
						score+=dps*length/samples
					end
				end
			end
		end
	end
	return score
end
function Routes.Choose(paths,wave,movement,towers,config,sequence)
	if wave<=5 then return 1 end
	if wave<=10 then return (sequence-1)%#paths+1 end
	-- Weighted choice leaves occasional pressure on defended lanes.
	local weights,total={},0
	for i,path in paths do
		weights[i]=1/(1+Routes.Score(path,movement,towers,config)/400)
		total+=weights[i]
	end
	local roll=rng:NextNumber()*total
	for i,weight in weights do
		roll-=weight
		if roll<=0 then return i end
	end
	return #paths
end
function Routes.Wave(number,config)
	if config.Waves[number] then return config.Waves[number] end
	local n=number-5
	local groups={
		{Type="Grunt",Count=8+n*2,Spacing=0.55},
		{Type="Runner",Count=5+n,Spacing=0.4},
		{Type="Flyer",Count=5+n,Spacing=0.6},
		{Type="Tank",Count=2+math.floor(n/2),Spacing=0.9},
	}
	if number%5==0 then table.insert(groups,{Type="Boss",Count=math.floor(number/5),Spacing=2}) end
	return groups
end
return Routes

