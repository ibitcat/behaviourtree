-- 龙人刺客

local _skill1 = 901401001   --普通攻击
local _skill02 = 901407001  --隐身刺杀      
local _skill2 = 901405001   --隐身刺杀前奏    
local _skill03 = 901406001  --隐身绷带      
local _skill3 =  901404001  --隐身绷带前奏   
local _skill4 = 901408001   --三连旋转飞刀
local _skill7 = 901410001   --二连旋转飞刀
local _skill5 = 901402001   --死亡之舞
local _cishaBuff = 147      --刺杀buff

oo.class("CikeBrain","Brain")
function CikeBrain:__init(owner)
	Brain.__init(self,owner)
	self._lastHpPercent = nil
	self._isFirst50Hp = nil	--是否第一次hp低于50%
	self._isFirst15Hp = nil	--是否第一次hp低于15%
	self._controlCount = 0	--10s内被控制次数
	self._feidaoCount = 0	--飞刀技能
end

function CikeBrain:getHpPercent()
	return self:getHp() / self:getHpUpper()
end

-- 每一次思考前，需要执行的逻辑
function CikeBrain:doUpdate()
	local ctm = env.unixtimeMs()
	-- 10s统计一次
	if not self._controlTime or ctm-self._controlTime>=10000 then
		self._controlCount = 0
		self._controlTime = ctm 
	else
		if self._controlCount>=6000 then
			self._controlCount = -1 --在10s内已经被控制超过6s了
		end
	end

	if self._owner:beControled() 
		and self._lastThinkTime>0
		and self._controlCount>=0
		and self._controlCount<6000 then
		self._controlCount = self._controlCount + (ctm-self._lastThinkTime)
	end
end

function CikeBrain:isCishaIng()
	return self._owner._buffContainer:hasBuff(1111)
end

function CikeBrain:cishaBefore()
	-- boss影身前的位置
	local x0,y0 = self._owner:getPixel()
	self:setValue('x0',x0)
	self:setValue('y0',y0)

	-- 加影身和无敌buff
	print("+影身和无敌buff")
	self:addBuff(1111)
	self:addBuff(102)
end

function CikeBrain:cishaBeforeEnd()
	local target = self:searchTarget()
	if target then
		local x0 = self:getValue('x0')
		local y0 = self:getValue('y0')
		local x,y= target:getPixel()
		if math.abs(x - x0) > math.abs(y - y0) then
			if x > x0 then
				x = x - 120
			else
				x = x + 120
			end
		else
			if y > y0 then
				y = y - 120
			else
				y = y + 120
			end
		end

		-- 瞬移到锁定目标附近
		local map = self._owner:getMapInstance()
		map:moveToPixel(self._owner, x, y)
	end

	self:removeBuff(1111)
	self:removeBuff(102)
	print("-影身和无敌buff")
end

function CikeBrain:addPugongCount()
	self._pgCount = (self._pgCount or 0) + 1
end

function CikeBrain:getInRangeObjNum(distance)
	local t = {}
	self:scanTargetInRange(distance,
		function(obj, dis)
			if not obj:isDead() 
				and obj~=self._owner
				and obj:isPlayer() then
				table.insert(t,obj)
			end
		end
	)
	return #t
end

function CikeBrain:beControl()
	if self._owner:isDead()
		or self._owner:isFloating()
		or self._owner:isFrozing()
		or self._owner:isDizzying() then
		return true
	end
	return false
end

function CikeBrain:checkPugong()
	local hpPrecent = self:getHpPercent()
	local ok = not self:isCishaIng() 
			and (self._pgCount or 0)>1 
			and self:getInRangeObjNum(10*120)>0 --3格
			--and self._owner:beControled() 
			--and (hpPrecent>0.5 and math.random(1,100)<=50) 
			--or (hpPrecent<=0.5 and math.random(1,100)<=75)
	if ok then print("---> ok") end
	return ok
end

-- 影身刺杀
function CikeBrain:cishaNode()
	return SequenceNode({
		SkillOnTarget({_skill2,lockTarget=true}, nil, function() self:cishaBefore() end),
		IfElseNode(function() return not self:searchTarget() end,
				NotDecorator(ActionNode(function() self:cishaBeforeEnd() end)),
				ActionNode()
			),
		WaitNode(3000),
		SkillOnTarget({_skill02,lockTarget=true}, function() self:cishaBeforeEnd() end),
		-- 刺杀成功后，释放一次普通攻击，并记录该目标
		IfNode(function()
				local tar = self:lockedTarget()
				local ok = tar and tar._buffContainer:hasBuff(_cishaBuff)
				if ok then print("刺杀成功后，释放一次普通攻击，并记录该目标") end
				return ok
			end,
			SkillOnTarget({_skill1},nil,function() self:unlockTarget() end)
		)
	})
end

-- 连续两次普攻，释放死亡之舞
function CikeBrain:pugongNode()
	return SequenceNode({
		SkillOnTarget({_skill1}),
		ActionNode(function() self:addPugongCount() end),
		IfNode(function() return self:checkPugong() end, 
			SequenceNode({
				ActionNode(function() self._pgCount=0 end),
				WaitNode(500),
				self:swzwNode()
			})
		)
	})
end

-- 释放死亡之舞成功后连续技,如果target是否在4格子内，是则 普攻，否则 选择一个目标，普攻
function CikeBrain:swzwNode()
	return SequenceNode({
		ActionNode(function() print("swzw开始") end),
		SkillOnTarget({_skill5, lockTarget=true}),
		ActionNode(function() print("swzw结束") end),
		IfElseNode(function() return self:isInRange(self:lockedTarget(),4*120) end,
			SkillOnTarget({_skill1}),
			SkillOnTarget({_skill1},function() self:unlockTarget() end)
		)
	})
end

-- 旋转飞刀连续技
function CikeBrain:xzfdNode()
	return SequenceNode({
		SkillOnTarget({_skill4}),
		IfNode(function() return self:getHpPercent()>0.5 and math.random(1,100) <= 50 end,
			SequenceNode({
				ActionNode(function() self._loopCout = math.random(1,2) end),
				LoopNode({SkillOnTarget({_skill4})}, self._loopCount or 0)
			})
		),
		IfNode(function() return self:getHpPercent()<0.5 end,
			SequenceNode({
				ActionNode(function() self._loopCout = math.random(1,3) end),
				LoopNode({SkillOnTarget({_skill4})}, self._loopCount or 0)
			})
		)
	})
end

function CikeBrain:onStart()
	local root = PriorityNode({
			-- 回家
			IfNode(function() return self:needGoHome() end, GoHome()),

			-- 搜索目标
			--NotDecorator(DoActionNode(function() return self:searchTarget() end)),

			-- 没有目标就巡逻
			--IfNode(function() return not self:searchTarget() end,PatrolTo()),

			-- 求救信号
			AlarmHelp(),

			-- 是否10s被控制6s
			--IfNode(function() return self._controlCount>=6000 end, self:swzwNode()),

			-- 被控制，则暂停思考(影身刺杀不能被打断)
			DoActionNode(function() return not self:isCishaIng() and self:beControl() end),
			-- 寻路战斗
			PatrolFight({skills={_skill7,_skill1},path={22,31,22,27,22,22},speed=300}),

			-- hp>50%
			WhileNode(function() return self:getHpPercent()>0.5 end, SelectorNode({
					-- 第一次进入战斗
					IfNode(function() return not self._isFirstHp end, 
						SequenceNode({
							ActionNode(function() self._isFirstHp = 1 end),
							self:cishaNode()
						})
					),
					
					-- 15s 释放一次刺杀
					--TimeDecorator(15000, IfNode(function() return self:skillCoolDowned(_skill2) and math.random(1,100) <= 50 end, self:cishaNode())),

					-- 5s  释放一次死亡之舞
					--TimeDecorator(5000, IfNode(function() return self:skillCoolDowned(_skill5) and math.random(1,100) <= 50 end, self:swzwNode())),

					-- 50% 释放旋转飞刀
					--IfNode(function() return self:skillCoolDowned(_skill4) and math.random(1,100)<=50 end, self:xzfdNode()),

					-- 普通攻击
					IfNode(function() return self:skillCoolDowned(_skill1) end, self:pugongNode()),
				})
			),

			-- 50%>hp>15%
			-- hp>50%
			--[[
			WhileNode(function() return self:getHpPercent()<=0.5 and self:getHpPercent()>=0.15 end, SelectorNode({
					-- 第一次hp低于50%
					IfNode(function() return not self._isFirst50Hp end,
						SequenceNode({
							ActionNode(function() self._isFirst50Hp = 1 end),
							IfElseNode(
								function() return self:getInRangeObjNum(4*120)>0 end,
								SequenceNode({self:swzwNode(), SkillOnTarget({_skill3}), SkillOnTarget({_skill03})}),
								SkillOnTarget({_skill3})
							)
						})
					),

					-- 每隔10s有50%概率释放刺杀隐身加刺杀，或者回复隐身加回复
					TimeDecorator(10000, IfNode(function() return self:skillCoolDowned(_skill2) end, self:cishaNode()), true),

					-- 5s 释放一次死亡之舞
					--TimeDecorator(5000, 
					--	IfNode(function() return self:skillCoolDowned(_skill5) and math.random(1,100)<=50 and self:getInRangeObjNum()>0 end, SkillOnTarget({_skill5})
					--)),
				})
			),

			-- hp<15%
			WhileNode(function() return self:getHpPercent()<=0.15 end, SelectorNode({
					IfNode(function() return not self._isFirst15Hp end,
						ActionNode(function() print("第一次低于15%")self._isFirst15Hp = 1 end)
					),

					-- 每隔5s有50%概率释放刺杀隐身加刺杀，如果上一个5s没有释放，则本次一定释放
					TimeDecorator(5000, SelectorNode({
							IfNode(function() return self._aaa==1 end, self:cishaNode(), ActionNode(function() self._aaa=0 end)),
							IfElseNode(function() return math.random(1,100) <= 50 end, self:cishaNode(), ActionNode(function() self._aaa=1 end))
						}), 
						true
					),
				})
			)
			]]
		},
		1000 --300ms 思考一次
	)

	self._bt = BehaviourTree(self._owner, root)
end