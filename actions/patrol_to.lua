-- patrol to
-- 巡逻行为

oo.class("PatrolTo","BehaviourNode")
function PatrolTo:__init(param)
	BehaviourNode.__init(self, nil, true)
	self._kind = "PatrolTo"
	self._param = param or {}
	self._ctx = {}
	self._stopTime = 500 -- 停顿时间
end

function PatrolTo:reset()
	BehaviourNode.reset(self)
	table.clear(self._ctx)
end

-- 选择一个点进行巡逻
function PatrolTo:pick()
	local owner = self._brain:getOwner()
	local conf = self._brain:getConfig()
	local patrolRange = conf.patrolRange or 0
	if patrolRange > 0 then
		local per = conf.patrolRate or 0
		if per > 0 and math.random(1, 100) < per then
			local x, y = owner:getBornCell()
			x = x + math.random(0 - patrolRange, patrolRange)
			y = y + math.random(0 - patrolRange, patrolRange)

			local speed = conf.patrolSpeed or 0
			speed = speed>0 and speed or 300
			self._ctx = {x=x,y=y,speed=speed}
		end
	end
end

-- 不会失败，只会running和success
function PatrolTo:visit()
	local owner = self._brain:getOwner()
	if self._status == BT.READY then
		self:pick()
	end

	local x,y,speed = self._ctx.x, self._ctx.y, self._ctx.speed
	if x and y and speed then
		self._status = BT.RUNNING
		local map = owner:getMapInstance()
		if not map:canMove(x, y) or owner:isInCell(x, y) then
			-- 到点了重新选择一个目标点
			--self:pick()
			--self:sleep(1000)
			self._status = BT.SUCCESS
			return
		else
			-- 开始移动
			if not owner:isMoving() then
				local param = self._param
				owner:moveStartCell(x, y, speed)
			end
		end
		self:sleep(1000)
	end
end