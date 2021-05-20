-- 大脑的api，这些api与具体的项目有耦合，所以单独拆出来
-- 如果需要移植，这个api是 非必要的
-- 这个文件里面的接口是action调用的

local _mathRandom = math.random

function Brain:initApi()
	self._state = nil 			--大脑的行为状态（状态机）
	self._currentTarget	= nil 	--ai这一次思考的可攻击目标
	self._scannedTarget = nil 	--主动怪搜索到的可攻击目标
	self._attackTarget  = nil 	--随机到的攻击目标
	self._selectTargetVersion = nil
end

function Brain:getConfig()
	return self._owner:getConfig()
end

function Brain:setValue(name, val)
	self._blackboard[name] = val
end

function Brain:getValue(name)
	return self._blackboard[name]
end

function Brain:getState()
	return self._state
end

function Brain:setState(s)
	self._state = s
end

function Brain:getThinkType()
	local cnf = self:getConfig()
	return cnf and cnf.thinkType
end

-- 技能是否冷却完
function Brain:skillCoolDowned(skillId)
	if skillId then
		return not self._owner._skillCT:hasCd(skillId)
	end
end

-- 目标是否在范围内
function Brain:isInRange(target, distance)
	if not target or not target:isValid() or target:isDead()
		or not SkillTargetSelector.canBeTarget(self._owner, target)
		or not self:isTargetInTraceRange(target) then
		return false
	end

	if distance then
		local dis = Utils.objPixelDistance(self._owner, target)
		return dis <= distance
	end

	return true
end

-- 目标是否在我的追踪范围内
function Brain:isTargetInTraceRange(target)
	local bx, by
	local cnf = self:getConfig()
	if cnf.basePoint == 1 then
		bx, by = self._owner:getPixel()
	else
		bx, by = self._owner:getBornPixel()
	end

	local dis = Utils.distance(bx, by, target:getPixel())
	if dis/CELL_PIXEL <= cnf.traceRange then
		return true, dis
	end
	return false, dis
end

-- 在索敌范围内搜索敌人
function Brain:selectEnemyInScanRange()
	local target
	local minDis = 0xffffffff
	local yes, dis
	local cnf = self:getConfig()
	local range = cnf.scanRange or 0
	if range > 0 then
		local map = self._owner:getMapInstance()
		if not map then return end

		local traceRange = cnf.traceRange or 0
		range = range > traceRange and traceRange or range
		if (cnf.basePoint or 0) == 1 then
			-- base=1,以当前位置为基点
			map:scanAroundTargetByObj(self._owner, range,
				function(obj)
					yes, dis = self:isTargetInTraceRange(obj)
					if SkillTargetSelector.canBeTarget(self._owner, obj) and yes then
						if dis < minDis then
							minDis = dis
							target = obj
						end
					end
				end
			)
		else
			-- base=0,以出生点为基准
			local bx, by = self._owner:getBornCell()
			map:scanAroundTargetByXy(bx, by, range,
				function(obj)
					yes, dis = self:isTargetInTraceRange(obj)
					if SkillTargetSelector.canBeTarget(self._owner, obj) and yes then
						if dis < minDis then
							minDis = dis
							target = obj
						end
					end
				end,
				self._owner
			)
		end
	end
	return target
end

-- 从攻击者中随机选择一个做个目标
function Brain:selectTargetFromAttackers()
	local list = self._owner:getAttackers()
	if list then
		local amt = #list
		if amt>0 then
			local idx = _mathRandom(1, amt)
			return list[idx]
		end
	end
end

-- 这个接口返回敌对的对象
function Brain:scanTargetInRange(distance, cb)
	local dist
	local ob
	local map = self._owner:getMapInstance()
	if not map then return end

	map:scanAroundTargetByObj(self._owner, math.ceil(distance/CELL_PIXEL),
		function(obj)
			if Utils.canBeTarget(self._owner, obj) then
				local dis = Utils.objPixelDistance(self._owner, obj)
				if dis <= distance then
					if cb(obj, dis) then
						ob = obj
						dist = dis
						return obj, dis
					end
				end
			end
		end
	)
	return ob, dist
end

--这个接口返回所有对象(友好/敌对)
function Brain:scanObjsInRange(distance, cb)
	local dist
	local ob
	local map = self._owner:getMapInstance()
	if not map then
		return
	end
	map:scanAroundByObj(self._owner, math.ceil(distance/CELL_PIXEL),
		function(obj)
			local dis = Utils.objPixelDistance(self._owner, obj)
			if dis <= distance then
				if cb(obj, dis) then
					ob = obj
					dist = dis
					return obj, dis
				end
			end
		end
	)
	return ob, dist
end

function Brain:selectTarget()
	if self._selectTargetVersion == self._thinkVersion then
		return self._currentTarget
	end

	-- 归位中，无目标
	if self:getState()=="goingHome" then return end

	-- 首刀攻击者
	local owner = self._owner
	local target = owner:getFirstAttacker()
	if target then
		if not self:isInRange(target) then
			target = nil
			owner:removeFirstAttacker()
		else
			self._attackTarget = nil
			self._scannedTarget = nil
		end
	end

	if not target then
		-- 从攻击者中随机一个目标
		target = self._attackTarget
		if not self:isInRange(target) then
			target = self:selectTargetFromAttackers()
			if not self:isInRange(target) then
				target = nil
			else
				self._attackTarget = target
			end
		else
			self._scannedTarget = nil
		end
	end

	-- 主动怪从索敌范围内搜寻目标
	local thinkType = self:getThinkType()
	if thinkType~=1 then
		if not target then
			target = self._scannedTarget
			if not self:isInRange(target) then
				-- 重新搜索一次
				target = self:selectEnemyInScanRange()
				if not self:isInRange(target) then
					target = nil
				else
					self._scannedTarget = target
					self._attackTarget = nil
				end
			else
				self._attackTarget = nil
			end
		end
	end
	self._currentTarget = target
	self._selectTargetVersion = self._thinkVersion
	return target
end