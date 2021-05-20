-- patrolFight 动作
-- 如果有目标则追踪目标，释放技能，否则，按照path巡逻

-- param = {skills={_skill7,_skill1}, path={22,31,22,27,22,22}, speed=300}

oo.class("PatrolFight","BehaviourNode")
function PatrolFight:__init(param)
	BehaviourNode.__init(self, nil, true)
	self._kind = "PatrolFight"
	self._param = param or {}
	self._ctx = {}

	assert(self._param.skills)
	local path = self._param.path
	assert(path)
	assert(#path>0 and (#path%2==0))
end

function PatrolFight:reset()
	BehaviourNode.reset(self)
	table.clear(self._ctx)
end

-- 不会失败，只会running和success
function PatrolFight:visit()
	local ret = self:evaluate()
	--print("PatrolFight ret = ",ret)
	if ret==0 then
		self._status = BT.SUCCESS
		table.clear(self._ctx)
	elseif ret>0 then
		self._status = BT.RUNNING
		self:sleep(ret)
	else
		self._status = BT.FAILED
		table.clear(self._ctx)
	end
end

function PatrolFight:evaluate()
	local brain = self._brain
	local owner = brain:getOwner()
	local skillCon = owner._skillCT

	local target = brain:searchTarget()
	local ctx = self._ctx
	local param = self._param
	if ctx.state == 'traceTarget' then
		if not target then
			-- 没有目标，下一次思考就开始巡逻
			ctx.state = 'patrol'
			return 1000
		else
			-- 找到一个可以释放的技能
			if not ctx.nextSkill then
				for _, skillId in pairs(param.skills) do
					if skillCon:hasCd(skillId) then
						ctx.nextSkill = skillId
						break
					end
				end
			end

			local skillId = ctx.nextSkill
			if skillId then
				if not brain:isTargetInSKillRange(skillId, target) then
					--local skillDistance = skillCon:getSkillDistance(skillId)
					local skillDistance = 160
					owner:traceTarget(target, skillDistance/CELL_PIXEL)
					owner:tracingUpdate()
					return 1000
				else
					ctx.nextSkill = nil
					owner:moveStop()
					print("释放技能，", skillId)
					--skillCon:castOnObjRaw(skillId, target)
					return 1000
				end
			end
		end
	end

	if target then
		ctx.state = 'traceTarget'
		return 300
	else
		if not owner:isTracing(nil) then
			owner:traceTarget(nil)
		end
	end

	-- 巡逻
	if owner:isMoving() then
		return 1000
	end

	-- 从第一个点开始走
	if not ctx.pathIdx then
		ctx.pathIdx = 1
	end

	local x, y = param.path[2*(ctx.pathIdx-1) + 1], param.path[2*(ctx.pathIdx-1)+2]
	if x and y and not owner:isMoving() then
		if owner:isInCell(x,y) then
			-- 下一个寻路点
			ctx.pathIdx = ctx.pathIdx + 1
		else
			local speed = param.speed or owner:getSpeed()
			if speed > 0 then
				local px, py = owner:getMapInstance():translateCellToPixel(x, y)
				owner:moveStart(px, py, speed)
			end
		end
	else
		-- 全部点都走完了,再从头开始走
		return 0
	end

	return 1000
end