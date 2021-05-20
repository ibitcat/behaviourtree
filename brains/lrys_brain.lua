-- 龙人勇士人形

local _sk_pugong = 901001001 			--普攻4恋姬
local _sk_mielongbao = 901011001		--灭龙爆
local _sk_qingyapo = 901012001 			--青牙破准备
local _sk_qingyapogongji = 901013001	--青牙破攻击
local _sk_qingyaposhangtiao = 901014001 --青牙破上挑
local _sk_zhanlongji = 901015001		--斩龙击
local _sk_bafanglongying = 901016001	--八方荒龙影
local _sk_qingyapolianxuji = 901019001	--青牙破连续技
local _sk_ranshaogongji = 901017001		--燃烧攻击
local _bf_mielongbao = 9010001			--灭龙爆命中buff

local _bianjieX = {6,31}
local _bianjieY = {6,31}
local _xiaowuX = {3,14}
local _xiaowuY = {25,33}

-- 普攻3次后的技能概率
local _sk_pool = {
	[3] = {{_sk_qingyapo, 0}, {_sk_mielongbao,20}, {_sk_zhanlongji,30}},
	[4] = {{_sk_qingyapo, 5}, {_sk_mielongbao,20}, {_sk_zhanlongji,35}},
	[5] = {{_sk_qingyapo, 5}, {_sk_mielongbao,25}, {_sk_zhanlongji,40}},
	[6] = {{_sk_qingyapo,10}, {_sk_mielongbao,40}, {_sk_zhanlongji,30}},
	[7] = {{_sk_qingyapo,35}, {_sk_mielongbao,30}, {_sk_zhanlongji,25}},
	[8] = {{_sk_qingyapo,100}, {_sk_mielongbao,0}, {_sk_zhanlongji, 0}}
}

-- 普攻3次后的技能概率
local _usk_pool = {
	[100] = {{_sk_bafanglongying, 0}, {_sk_qingyapolianxuji, 0}},
	[70]  = {{_sk_bafanglongying,50}, {_sk_qingyapolianxuji, 0}},
	[30]  = {{_sk_bafanglongying,50}, {_sk_qingyapolianxuji,50}}
}

-- 5次技能后的触发灭龙爆的概率
local _mlbsk_pool = {{6,50},{7,50},{8,100}}


local function getJumpSpeed(cx,cy,x,y) --jump 2850ms
	if x ~= cx or y ~= cy then
		local dis = Utils.distance(cx,cy,x,y)
		local speed = math.floor(dis*120/1.3)
		return speed
	else
		return 500
	end
	return 500
end

local function luanchong(ax,ay,bx,by)
	local x1 = _bianjieX[1]
	local x2 = _bianjieX[2]
	local y1 = _bianjieY[1]
	local y2 = _bianjieY[2]
	local x3 = _xiaowuX[1]
	local x4 = _xiaowuX[2]
	local y3 = _xiaowuY[1]
	local y4 = _xiaowuY[2]
	local x
	local y 
	--直线方程 y=kx + b
	if ax == bx or ay == by then
		if ax == bx then
			if ay - by >=0 then 
				y = y1
				x = ax
			else 
				y = y2
				x = ax
			end
			if x >= x3 and x <= x4 and y >= y3 and y <= y4 then
				if y3 >= y1 and y3 <= y2 then
					y = y3
				else
					y = y4
				end
			end
		else
			if ax - bx >= 0 then
				x = x1
				y = ay
			else
				x = x2
				y = ay
			end
			if x >= x3 and x <= x4 and y >= y3 and y <= y4 then
				if x3 >= x1 and x3 <= x2 then
					x = x3
				else
					x = x4
				end
			end
		end

		return x,y
	else 
		local k = (ay-by)/(ax-bx)
		local b = ay - ax*k 
		--求与直线x1,x2,y1,y2的交点
		local aa = {}
		local bb = {}
		--x1
		local cy1 = k*x1+b 
		table.insert(aa,{x1,cy1})
		--x2
		local cy2 = k*x2+b 
		table.insert(aa,{x2,cy2})
		--y1
		local cx1 = (y1-b)/k
		table.insert(aa,{cx1,y1})
		--y2
		local cx2 = (y2-b)/k
		table.insert(aa,{cx2,y2})
		--x3
		local cy3 = k*x3+b 
		table.insert(bb,{x3,cy3})
		--x4
		local cy4 = k*x4+b 
		table.insert(bb,{x4,cy4})
		--y3
		local cx3 = (y3-b)/k
		table.insert(bb,{cx3,y3})
		--y4 
		local cx4 = (y4-b)/k
		table.insert(bb,{cx4,y4})
		for _,v in pairs(bb) do
			if v[1]>=x3 and v[1]<=x4 and v[2]>=y3 and v[2]<=y4 and v[1]>=x1 and v[1]<=x2 and v[2]>=y1 and v[2]<=y2 then
				if math.abs(Utils.computeAngle(ax, ay, bx, by) - Utils.computeAngle(ax,ay,v[1],v[2])) < 2 then
					x= math.floor(v[1])
					y= math.floor(v[2])
					break
				end
			end
		end	
		if x and y then
			return x,y
		end	
		for _,v in pairs(aa) do 
			if v[1]>=x1 and v[1]<=x2 and v[2]>=y1 and v[2]<=y2 then
				if math.abs(Utils.computeAngle(ax, ay, bx, by) - Utils.computeAngle(ax,ay,v[1],v[2])) < 2 then
					x= math.floor(v[1])
					y= math.floor(v[2])
					break
				end
			end
		end
		if x and y then
			return x,y
		end
	end
	return nil,nil
end

oo.class("LrysBrain","Brain")
function LrysBrain:__init(owner)
	Brain.__init(self,owner)
end

-- 死亡之后，清除召唤的小怪
function LrysBrain:onStop()
	self._owner:removeAllSummon()
end

function LrysBrain:getHpPercent()
	return self:getHp() / self:getHpUpper()
end

-- 普攻次数+1
function LrysBrain:addPgCount()
	local old = self:getValue("putongCount")
	self:setValue("putongCount", (old or 0) + 1)
end

-- 普通技能次数+1
function LrysBrain:addSkillCount()
	local old = self:getValue("weiyiCount")
	self:setValue("weiyiCount", (old or 0) + 1)
end

-- 灭龙破是否有命中目标
function LrysBrain:hasMlpTarget()
	local map = self._owner:getMapInstance()
	local plrs = map:getObjs(OBJ_TYPE.PLAYER)
	for _,plr in pairs(plrs) do
		if plr._buffContainer:hasBuff(_bf_mielongbao) then
			self:addSkillCount()
			return true
		end
	end
end

-- 随机一个大招
function LrysBrain:randomUniqueSkill()
	local t
	local m = 999
	local hpPer = self:getHp()/self:getHpUpper()*100
	for per,v in pairs(_usk_pool) do
		if hpPer<per and per<m then
			m = per
			t = v
		end
	end
	if not t then return end

	local times = self:getValue("uskTimes") or 1
	local totol = 0
	for _,v in pairs(t) do
		totol = totol + v[2]*(times or 1)
	end

	local ran
	if totol > 100 then
		ran = math.random(1,totol)
	else
		ran = math.random(1,100)
	end

	local weigh = 0
	local skillId
	for _,vv in ipairs(t) do 
		weigh = weigh + vv[2]*times
		if weigh >= ran then
			skillId = vv[1]
			break
		end
	end

	if skillId then
		self:setValue("uskillId",skillId)
		self:setValue("uskTimes", 1)
		print("随机到的大招技能 = ",skillId)
		return true
	else
		-- 概率增大一倍
		self:setValue("uskTimes",times + 1)
	end
end

-- 3次普攻后随机一个技能
function LrysBrain:randomSkill()
	local count = self:getValue("putongCount")
	if not count or count<3 then return end
	
	local t
	local m = 0
	for i,v in pairs(_sk_pool) do
		if count>=i and i>m then
			m = i
			t = v
		end
	end
	if not t then return end

	local skillId
	local ran = math.random(1,100)
	local weigh = 0
	for _,vv in ipairs(t) do
		weigh = weigh + vv[2]
		if weigh >= ran then
			skillId = vv[1]
			break
		end
	end

	if skillId then
		self:setValue("skillId",skillId)
		self:setValue("putongCount", 0)
		print("3次普攻随机到的技能 = ",skillId,count)
		return true
	end
end

-- 5次技能收随机灭龙爆技能
function LrysBrain:randomMlbSkill()
	local count = self:getValue("weiyiCount") or 0
	if count < 5 then return end
	
	local per
	for _,v in ipairs(_mlbsk_pool) do
		if count<v[1] then
			break
		else
			per = v[2]
		end
	end

	if per then
		local ran = math.random(1,100)
		if ran<=per then
			self:setValue("weiyiCount",nil)
			return true
		end
	end
end

-- 能否触发青牙破（周围4格内无目标，且概率为75%）
function LrysBrain:canQypSkill()
	-- 75%概率
	if math.random(1,100) > 75 then
		return
	end

	local t = {}
	self:scanTargetInRange(1800,
		function(obj, dis)
			if not obj:isDead() 
				and obj:isPlayer() 
				and obj~=self._owner
				and dis <= 480 then --4格内无目标
				table.insert(t,obj)
			end
		end
	)
	return #t==0
end

-- 选择青牙破技能的目标
function LrysBrain:selectQypTarget()
	local t = {}
	self:scanTargetInRange(1800,
		function(obj, dis)
			if not obj:isDead() 
				and obj:isPlayer() 
				and obj~=self._owner then
				table.insert(t,obj)
			end
		end
	)

	local target
	if #t>0 then
		target = t[math.random(1,#t)]
		self:lockTarget(target)
		return true
	end
end

-- 选择斩龙击的目标
function LrysBrain:selectZljTarget()
	local t = {}
	local curTarget = self:currentTarget()
	self:scanTargetInRange(800,
		function(obj, dis)
			if not obj:isDead() 
				and obj:isPlayer() 
				and obj ~= self._owner
				and obj ~= curTarget then
				table.insert(t,obj)
			end
		end
	)

	local target
	if #t > 0 then
		target = t[1]
	else
		target = curTarget
	end
	if not target then return end
	
	self:lockTarget(target)
	return true
end

-- 斩龙击后跳
function LrysBrain:backJump(node)
	local target = self:searchTarget()
	if not target then return end

	local tpx,tpy = target:getPixel()
	local px,py = self._owner:getPixel()
	local degree = Utils.computeAngle(tpx, tpy, px, py)
	local rad = math.rad(degree)
	local map = self._owner:getMapInstance()
	local x
	local y 
	for i=3,1,-1 do 
		px = math.floor( i*120 * math.cos(rad) ) + px
		py = math.floor( i*120 * math.sin(rad) ) + py
		x,y = map:translatePixelToCell(px,py)
		if x and map:canMove(x,y) then
			local x1,y1 = self._owner:getCell()
			local speed = getJumpSpeed(x,y,x1,y1)
			if node and node.resetParam then
				node:resetParam({x=x,y=y,speed = speed,act = 'jump'})
			end
		end
	end
end

-- 大招八方，跳到地图中心（主要是改变速度）
function LrysBrain:jumpCenter(node)
	local x1,y1 = self._owner:getCell()
	local speed = getJumpSpeed(19,24,x1,y1)
	if node and node.resetParam then
		node:resetParam({speed = speed})
	end
end

-- 八方技能的小怪(通知小怪释放浮空技能)
function LrysBrain:bafangSummon()
	local map = self._owner:getMapInstance()
	local mons = map:getObjs(OBJ_TYPE.MONSTER)
	for _,mon in pairs(mons) do
		local cnf = mon:getConfig()
		local aiId = cnf.ai
		if aiId == 900551 then
			local ai = mon.getAI and mon:getAI()
			if ai then
				ai:setValue('baojuhuatime',self:currentTime()+1000)
			end
		end
	end
end

-- 大招青牙破连续击
function LrysBrain:getTargets()
	local t = {}
	self:scanTargetInRange(4000,
		function(obj, dis)
			if not obj:isDead() and obj:isPlayer() then
				table.insert(t,obj)
			end
		end
	)
	if #t>0 then
		local oldLen = #t
		for i=1,oldLen do
			t[oldLen+i] = t[i]
		end
		self:setValue("targets",t)
		self:setValue("index",nil)
		return true
	end
end

function LrysBrain:rotationTarget(node)
	local t = self:getValue("targets")
	local idx = self:getValue("index") or 0 
	idx = idx + 1
	self:setValue("index",idx)
	local target = t[idx]
	self:lockTarget(target)

	local ax,ay = self._owner:getCell()
	local bx,by = target:getCell()
	local x,y = luanchong(ax,ay,bx,by)
	return {x=x, y=y}
end

-------------------------------------- node --------------------------------------
-- 灭龙破，以及连续技
function LrysBrain:mielongbaoNode()
	return SequenceNode({
		SkillOnTarget({_sk_mielongbao},nil,function() self:addSkillCount() end),
		ActionNode(function() print("-------->灭龙破，以及连续技") end),
		WaitNode(1000), --有蛋疼的问题
		IfNode(function() return self:hasMlpTarget() end,
			SkillOnTargetCombo({_sk_qingyapo, _sk_qingyapogongji, _sk_qingyaposhangtiao})
		)
	})
end

-- 青牙破，以及连续技
function LrysBrain:qingyapoNode()
	-- 先要切换目标
	return IfNode(function() return self:selectQypTarget() end,
		SkillOnTargetCombo({_sk_qingyapo, _sk_qingyapogongji, _sk_qingyaposhangtiao},nil,function() self:addSkillCount() end)
	) 
end

-- 斩龙击
function LrysBrain:zhanlongjiNode()
	return SequenceNode({
		DoActionNode(function() return self:selectZljTarget() end),
		MoveTo(nil, function(node) self:backJump(node) end),
		WaitNode(500),
		SkillOnTarget({_sk_zhanlongji},nil,function() self:addSkillCount() end)
	})
end

-- 大招-八方荒龙影
function LrysBrain:bafangNode()
	return SequenceNode({
		MoveTo({x=19,y=24,act='jump'}, function(node) self:jumpCenter(node) end),
		SkillOnTarget({_sk_bafanglongying}),
		ActionNode(function() self:bafangSummon() end)
	})
end

-- 大招-青牙破连续击
function LrysBrain:qingyapoLxjNode()
	return IfNode(function() return self:getTargets() end,
		LoopNode({
			SequenceNode({
				SkillOnTarget({_sk_qingyapolianxuji}),
				RunWithSkill({901020001,speed=2000,act="skillb2"}, nil, function() return self:rotationTarget() end)
			})},
			nil,
			function() return #(self:getValue("targets") or {}) end
		)
	)
end

function LrysBrain:onStart()
	local root = PriorityNode({
			IfNode(function() return self:needGoHome() end, GoHome()),
			DoActionNode(function() return self._owner:beControled() end),

			IfNode(function() return self:getHpPercent()<0.7 and not self._isFirst70Hp end, 
				SequenceNode({
					ActionNode(function() self._isFirst70Hp = 1 end),
					self:bafangNode()
				})
			),

			IfNode(function() return self:getHpPercent()<0.3 and not self._isFirst30Hp end, 
				SequenceNode({
					ActionNode(function() self._isFirst30Hp = 1 end),
					self:qingyapoLxjNode()
				})
			),

			-- 每30是检查一次大招
			TimeDecorator(30000, 
				IfNode(function() return self:randomUniqueSkill() end,
					SelectorNode({
						IfNode(function() return self:getValue("uskillId")==_sk_bafanglongying end, self:bafangNode()),
						IfNode(function() return self:getValue("uskillId")==_sk_qingyapolianxuji end, self:qingyapoLxjNode())
					})
				)
			),

			-- 3次以上普攻后随机除大招以外的技能
			IfNode(function() return self:randomSkill() end,
				SelectorNode({
					IfNode(function() return self:getValue("skillId")==_sk_mielongbao end, self:mielongbaoNode()),
					IfNode(function() return self:getValue("skillId")==_sk_qingyapo end, self:qingyapoNode()),
					IfNode(function() return self:getValue("skillId")==_sk_zhanlongji end, self:zhanlongjiNode())
				})
			),

			IfNode(function() return self:randomMlbSkill() end,self:mielongbaoNode()),

			-- 5秒检查一次青牙破技能
			TimeDecorator(5000, 
				IfNode(function() return self:canQypSkill() end,self:qingyapoNode()),
				true
			),

			-- 普攻
			IfNode(function() return self:skillCoolDowned(_sk_pugong) end,
				SkillOnTarget({_sk_pugong}, nil, function() self:addPgCount() self:addSkillCount() end)
			)
		},
		1000
	)

	self._bt = BehaviourTree(self._owner, root)
end
