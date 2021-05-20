-- 追踪节点

oo.class("Trace","BehaviourNode")
function Trace:__init(param, traceFn)
	BehaviourNode.__init(self, nil, true)
	self._kind = "Trace"
	self._param = param
	self._ctx = {}
	self._fn = traceFn
end

function Trace:reset()
	BehaviourNode.reset(self)
	table.clear(self._ctx)
end

function Trace:getTraceTarget()
	local brain = self._brain
	local target = self._ctx.target
	if target then
		if not target:isValid()
			or not brain:isTargetInTraceRange(target) then
			return
		end
		return target
	end

	target = self._fn and self._fn()
	if not target or not target:isValid()
		or not brain:isTargetInTraceRange(target) then
		return
	end

	self._ctx.target = target
	return target
end

function Trace:visit()
	local ret = self:evaluate()
	if ret==0 then
		self._status = BT.SUCCESS
	elseif ret>0 then
		self._status = BT.RUNNING
		self:sleep(ret)
	else
		self._status = BT.FAILED
	end
end

function Trace:evaluate()
	local target = self:getTraceTarget()
	if not target then
		return -1
	end

	local param = self._param
	local owner = self._brain:getOwner()
	if not self._ctx.flag then --开始追踪
		self._ctx.flag = true
		self._ctx.beginTime = env.unixtimeMs()

		if not owner:isTracing() then
			owner:traceTarget(target, (param.distance or 0)/CELL_PIXEL)
		end
	else
		if param.distance and Utils.objPixelDistance(owner, target) <= (param.distance + owner:getSize() + target:getSize()) then
			-- 追踪距离已满足
			return 0
		elseif param.keepTime and (env.unixtimeMs() - self._ctx.beginTime) >= param.keepTime then
			-- 追踪时间超时
			return 0
		end
	end

	-- update tracing
	if owner:isTracing() then
		owner:tracingUpdate()
	end
	return 1000
end