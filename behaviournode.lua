-- 行为树各类节点

--[[
行为树节点主要分为：
1、组合节点（序列节点、选择节点、并行节点等）
2、装饰节点（且只能有一个子节点）
3、条件节点
4、动作节点

只有条件节点和动作节点能做完行为树的叶子节点，
而组合、装饰节点控制行为树的决策走向，所以，
条件和动作节点称为行为节点（Behavior Node），
组合和装饰节点称为决策节点（Decider Node）。

只有叶子节点才需要特别定制。
--]]


-- 行为树节点父类
-- _needBrain 只有跟业务耦合的节点才需要，表示是否需要大脑，比如定制的gohome节点、逻辑先关的事件节点
-- 而其他中间节点，则与业务无关，它们只负责决策的走向，所以不需要owner，
-- 这样可以少一点owner的标记，减少gc
oo.class("BehaviourNode")
function BehaviourNode:__init(children, need)
	self._parent = nil
	self._brain = nil
	self._needBrain = need 			--是否需要实体的brain
	self._kind = "BehaviourNode"	--行为树节点种类
	self._nextUpdatetime = nil		--下一次更新时间
	self._children = children 		--子节点列表(数组)
	self._status = BT.READY			--当前状态
	self._lastresult = BT.READY		--上一次结果

	if children then
		assert(type(children)=="table")
		for _,child in ipairs(children) do
			child._parent = self
		end
	end
end

function BehaviourNode:setBrain(brain)
	if self._needBrain then
		self._brain = brain
		if self.onSetBrain then
			self:onSetBrain()
		end
	end

	if self._children then
		for k,child in ipairs(self._children) do
			child:setBrain(brain)
		end
	end
end

function BehaviourNode:getBrain()
	return self._brain
end

function BehaviourNode:getOwner()
	local brain = self:getBrain()
	if brain then
		return brain:getOwner()
	end
end

function BehaviourNode:iskindof(k)
	return self._kind == k
end

-- 从当前节点的父节点开始往上执行func函数
function BehaviourNode:doToParents(func)
	if self._parent then
		func(self._parent)
		return self._parent:doToParents(func)
	end
end

-- t至少大于10ms，切必须是10的倍数
-- 必须处于运行中才能睡眠
function BehaviourNode:sleep(t)
	assert(t>=10)
	assert(not self._children,"叶子节点才能睡眠")
	self._nextUpdatetime = env.unixtimeMs() + t
end

-- 只有处于运行中的叶子节点才有睡眠时间
function BehaviourNode:getSleepTime()
	-- 该节点正在运行并且没有子节点（也就是到了树的叶子节点），并且不是条件节点(其实就是行为节点)
	if self._status == BT.RUNNING
		and not self._children
		and not self:iskindof("ConditionNode") then
		if self._nextUpdatetime then
			local timeTo = self._nextUpdatetime - env.unixtimeMs()
			if timeTo>0 then
				return timeTo
			end
		end
		return 0
	end
end

-- 获取从该节点开始（包括该节点），最小的睡眠时间
function BehaviourNode:getTreeSleepTime()
	local sleeptime
	if self._children then --有子节点
		for _,child in ipairs(self._children) do
			if child._status==BT.RUNNING then
				local t = child:getTreeSleepTime()
				if t and (not sleeptime or t<sleeptime) then --找最小的sleeptime
					sleeptime = t
				end
			end
		end
	end

	local myTime = self:getSleepTime()
	if myTime and (not sleeptime or myTime<sleeptime) then
		sleeptime = myTime
	end
	return sleeptime
end

function BehaviourNode:toString()
	return ""
end

function BehaviourNode:getString()
	local str = ""
	if self._status == BT.RUNNING then
		str = self:toString()
	end
	if #str>0 then
		return string.format([[%s:[%s-->%s]:(%s)]], self._kind, self._lastresult or "?", self._status or "UNKNOWN", str)
	else
		return string.format("%s:[%s-->%s]", self._kind, self._lastresult or "?", self._status or "UNKNOWN")
	end
end

function BehaviourNode:getTreeString(indent)
	indent = indent or ""
	local str
	local sleepTime = self:getTreeSleepTime()
	if sleepTime then
		str = string.format("%s├─%s sleep:[%s]\n", indent, self:getString(), sleepTime)
	else
		str = string.format("%s├─%s\n", indent, self:getString())
	end

	if self._children then
		local isNotLast
		if self._parent and self._parent._children then
			local l = #self._parent._children
			isNotLast = self._parent._children[l]~=self
		end

		indent = indent..(isNotLast and "│  " or "   ")
		for _, child in ipairs(self._children) do
			str = str .. child:getTreeString(indent)
		end
	end
	return str
end

function BehaviourNode:visit()
	self._status = BT.FAILED
end

-- 保存上一次update的状态
function BehaviourNode:saveStatus()
	self._lastresult = self._status
	if self._children then
		for k,v in pairs(self._children) do
			v:saveStatus()
		end
	end
end

-- 步进
-- 如果该处于运行中并且有子节点，则步进子节点; 否则，重置该节点以及子节点
function BehaviourNode:step()
	if self._status ~= BT.RUNNING then
		self:reset()
	elseif self._children then
		for k, v in ipairs(self._children) do
			v:step()
		end
	end
end

-- 重置节点为ready状态
function BehaviourNode:reset()
	if self._status ~= BT.READY then
		self._status = BT.READY
		if self._children then
			for idx, child in ipairs(self._children) do
				child:reset()
			end
		end
	end
end

function BehaviourNode:stop()
	if self.onStop then
		self:onStop()
	end
	if self._children then
		for _, child in ipairs(self._children) do
			child:stop()
		end
	end
end

------------------------------------- 装饰节点 -------------------------------------
--[[
它将它的子节点执行后返回的结果值做额外处理后，再返回给它的父节点，装饰节点作为控制分支节点，必须且只接受一个子节点。
装饰节点的执行首先执行子节点，并根据自身的控制逻辑以及子节点的返回结果决定自身的状态。
主要包括：
loop 节点
not 节点
--]]
oo.class("DecoratorNode","BehaviourNode")
function DecoratorNode:__init(child)
   BehaviourNode.__init(self,{child})
   self._kind = "DecoratorNode"
end

-- not装饰节点
--[[
类似于逻辑“非”操作，非节点对子节点的返回值执行取反操作。
如果子节点状态为running，则将自身状态也设置为running，其他状态则取反。
--]]
oo.class("NotDecorator","DecoratorNode")
function NotDecorator:__init(child)
	DecoratorNode.__init(self,child)
	self._kind = "NotDecorator"
end

function NotDecorator:visit()
	local child = self._children[1]
	child:visit()

	local status = child._status
	if status == BT.SUCCESS then
		self._status = BT.FAILED
	elseif status == BT.FAILED then
		self._status = BT.SUCCESS
	else
		self._status = status
	end
end

-- time节点
-- 该节点的状态由子节点决定
-- 当子节点的返回的状态为成功（success）,则更新该节点的nextTime，否则，下一次visit继续尝试执行子节点
-- 该节点实现的逻辑：每隔一段时间尝试执行一次子节点，如果子节点返回成功，则继续下一次等待
-- any =true 表示无论子节点是否成功，则重置下一次执行的时间
oo.class("TimeDecorator","DecoratorNode")
function TimeDecorator:__init(wt, child, any)
	assert(child)
	DecoratorNode.__init(self, child)
	self._kind = "TimeDecorator"
	self._nextTime = 0		--下一次执行的时间戳
	self._waitTime = wt
	self._any = any
end

-- 如果未到下一次执行时间，visit返回的状态为READY
function TimeDecorator:visit()
	local ctm = env.unixtimeMs()
	if self._status == BT.RUNNING or ctm>=self._nextTime then
		local child = self._children[1]
		child:visit()
		self._status = child._status
	end

	if self._any then
		if self._status == BT.SUCCESS or self._status == BT.FAILED then
			self._nextTime = ctm + self._waitTime
		end
	else
		if self._status == BT.SUCCESS then
			self._nextTime = ctm + self._waitTime
		end
	end
end


------------------------------------- 条件节点 -------------------------------------
--[[
条件节点根据比较结果返回成功或失败，但永远不会返回正在执行（Running）
--]]
oo.class("ConditionNode","BehaviourNode")
function ConditionNode:__init(func)
	BehaviourNode.__init(self)
	self._kind = "ConditionNode"
	self._fn = func
	--self._param = param or {} --func的参数列表，{a,b,c}
end

-- 条件为true则返回成功
function ConditionNode:visit()
	if self._fn and self._fn() then
		self._status = BT.SUCCESS
	else
		self._status = BT.FAILED
	end
end

-- 条件等待节点
oo.class("ConditionWaitNode","BehaviourNode")
function ConditionWaitNode:__init(func)
	BehaviourNode.__init(self)
	self._kind = "ConditionWaitNode"
	self._fn = func
end

-- 和条件节点不一样的地方是：原来判断为失败的情况，现在判断为running
function ConditionWaitNode:visit()
	if self._fn and self._fn() then
		self._status = BT.SUCCESS
	else
		self._status = BT.RUNNING
	end
end

------------------------------------- 动作节点 -------------------------------------
-- 通常对应owner的某个方法，一般是个瞬间动作，比如放个技能、说一句话等
-- 如果是持续性动作，比如移动到某个点，需要用到bufferAction
oo.class("ActionNode","BehaviourNode")
function ActionNode:__init(action, resetFn)
	BehaviourNode.__init(self)
	self._kind = "ActionNode"
	self._action = action
	self._resetFn = resetFn
end

function ActionNode:reset()
	BehaviourNode.reset(self)
	if self._resetFn then
		self._resetFn()
	end
end

function ActionNode:visit()
	if self._action then
		self._action()
	end
	self._status = BT.SUCCESS
end

-- ActionDrtNode ，ActionNode装饰节点
-- 根据action的返回结果，决定该节点的状态
oo.class("ActionDrtNode","ActionNode")
function ActionDrtNode:__init(action, resetFn)
	ActionNode.__init(self, action, resetFn)
	self._kind = "ActionDrtNode"
end

function ActionDrtNode:visit()
	local ok = self._action()
	if ok then
		self._status = BT.SUCCESS
	else
		self._status = BT.FAILED
	end
end

------------------------------------- 组合节点 -------------------------------------
-- 序列节点
--[[
它实现的是and的逻辑，例如：r = x and y and z,则先执行x，如果x为true，则继续执行y，如果x为false，则直接返回false，以此类推
执行该节点时，它会一个接一个运行，
如果子节点状态为success，则执行下一个子节点；
如果子节点状态为running，则把自身设置为running，并等待返回其他结果（success或failed）；
如果子节点状态为failed，则把自身设置为failed，并返回；
如果所有节点都为success，则把自身设置为success并返回。
原则：只要一个子节点返回"失败"或"运行中"，则返回；若返回"成功"，则执行下一个子节点。
--]]
oo.class("SequenceNode","BehaviourNode")
function SequenceNode:__init(children)
	BehaviourNode.__init(self,children)
	self._kind = "SequenceNode"
	self._idx = 1 --正在运行的是第几个子节点
end

function SequenceNode:visit()
	if self._status~=BT.RUNNING then --如果没有运行的子节点，则从头开始执行
		self._idx = 1
	end

	local count = #self._children
	local child
	local status
	while self._idx<=count do
		child = self._children[self._idx]
		child:visit()
		status = child._status
		if status==BT.RUNNING or status==BT.FAILED then
			self._status = status
			return
		end

		self._idx = self._idx + 1
	end
	self._status = BT.SUCCESS --所有子节点都返回success
end

function SequenceNode:reset()
	self._idx = 1
	BehaviourNode.reset(self)
end

function SequenceNode:toString()
	return tostring(self._idx)
end

-- 选择节点
--[[
它实现的是or的逻辑，例如：r = x or y or z,则先执行x，如果x为false，则继续执行y，如果x为true，则直接返回true，以此类推
执行该节点时，它会一个接一个运行，
如果子节点状态为success，则把自身设置为success并返回；
如果子节点状态为running，则把自身设置为running，并等待返回其他结果（success或failed）；
如果子节点状态为failed，则会执行下一个子节点；
如果所有没子节点都不为success，则把自身设置为failed并返回。
原则：只要一个子节点返回"成功"或"运行中"，则返回；若返回"失败"，则执行下一个子节点。
--]]
oo.class("SelectorNode","BehaviourNode")
function SelectorNode:__init(children)
	BehaviourNode.__init(self,children)
	self._kind = "SelectorNode"
	self._idx = 1
end

function SelectorNode:visit()
	if self._status~=BT.RUNNING then
		self._idx = 1
	end

	local count = #self._children
	local child
	local status
	while self._idx<=count do
		child = self._children[self._idx]
		child:visit()
		status = child._status
		if status==BT.SUCCESS or status==BT.RUNNING then
			self._status = status
			return
		end
		self._idx = self._idx + 1
	end
	self._status = BT.FAILED
end

function SelectorNode:reset()
	self._idx = 1
	BehaviourNode.reset(self)
end

function SelectorNode:toString()
	return tostring(self._idx)
end

-- 并行节点
--[[
看上去是同时执行所有的子节点，但是真正的逻辑还是一个一个执行子节点。
如果子节点的状态是failed，则将自身设置为failed，并返回；
如果子节点是success或者running，则运行下一个子节点；
如果所有子节点都为success，则将自身设置为success并返回，否则设置自身为running。
在运行到该节点时，要对部分节点(ConditionNode、NotDecorator)做重置，重启判断。
ps:这里的实现的其实是Parallel Sequence Node，如果子节点failed,则返回。
并行节点可以设置退出条件，参考：
http://www.cnblogs.com/hammerc/p/5044815.html
--]]
oo.class("ParallelNode","BehaviourNode")
function ParallelNode:__init(children)
	BehaviourNode.__init(self,children)
	self._kind = "ParallelNode"
	self.stoponanycomplete = nil --只要有一个子节点返回成功，则该并行节点退出，并返回成功
end

function ParallelNode:visit()
	local done = true --是否所有子节点都success
	local any_done = false
	for _, child in ipairs(self._children) do
		if child:iskindof("ConditionNode") then --重启条件节点
			child:reset()
		end

		if child._status~=BT.SUCCESS then
			child:visit()
			if child._status == BT.FAILED then
				self._status = BT.FAILED
				return
			end
		end

		if child._status == BT.RUNNING then
			done = false
		else -- success
			any_done = true
		end
	end

	if done or (self.stoponanycomplete and any_done) then
		self._status = BT.SUCCESS
	else
		self._status = BT.RUNNING
	end
end

-- 并行节点如果不在"运行中"，则重置条件子节点
function ParallelNode:step()
	if self._status~=BT.RUNNING then
		self:reset()
	else
		--只重置条件子节点
		if self._children then
			for i,child in ipairs(self._children) do
				if self:iskindof("ConditionNode")
					and child._status==BT.SUCCESS then
					child:reset()
				end
			end
		end
	end
end

------------------------------------- 组合扩展节点 -------------------------------------
--while节点
--实现了while操作，ParallelNode的扩展
--直到条件不满足，则停止该节点
--注意：while节点的每一次思考，都会重启条件节点的判断，这与if节点不同。
oo.class("WhileNode","ParallelNode")
function WhileNode:__init(condFunc,node)
	local condNode = ConditionNode:new(condFunc)
	ParallelNode.__init(self,{condNode,node})
	self._kind = "WhileNode"
end

--if 节点
--实现了if操作，只有cond为success时，node才会被执行
--注意：如果node处于运行中，则会在下一次思考时，继续执行node节点，直到node返回成功或失败，该节点才会退出
--如果node节点有可能出现运行中状态，则该节点不适用，
--因为如果running，那么下一次think时，会跳过条件检查，直接从running的node节点开始执行
oo.class("IfNode","SequenceNode")
function IfNode:__init(condFunc,node)
	assert(node)
	local children = {ConditionNode:new(condFunc),node}
	SequenceNode.__init(self, children)
	self._kind = "IfNode"
end

-- ParallelNodeAny
-- ParallelNode的扩展节点，唯一不同的地方是：
-- 只要执行的子节点状态为success时，则会将自己设置为success并返回。
-- 当然，并行节点还是会将所有节点都执行一遍。
oo.class("ParallelNodeAny","ParallelNode")
function ParallelNodeAny:__init(children)
	ParallelNode.__init(self,children)
	self.stoponanycomplete = true	-- 只要子节点有一个是success状态，则并行节点状态也为success状态
	self._kind = "ParallelNodeAny"
end

-- ifelse 节点
-- 实现if else 的逻辑
oo.class("IfElseNode","BehaviourNode")
function IfElseNode:__init(condFunc,okNode,elseNode)
	assert(elseNode)
	BehaviourNode.__init(self, {ConditionNode:new(condFunc), okNode, elseNode})
	self._kind = "IfElseNode"
end

function IfElseNode:reset()
	self._idx = 1
	BehaviourNode.reset(self)
end

function IfElseNode:visit()
	if self._status~=BT.RUNNING then
		self._idx = 1

		local condNode = self._children[1]
		condNode:visit()
		local condStatus = condNode._status
		if condStatus==BT.SUCCESS then
			self._idx = 2
		elseif condStatus==BT.FAILED then
			self._idx = 3
		end
	end

	local child = self._children[self._idx]
	child:visit()
	self._status = child._status
end

------------------------------------- 其他节点 -------------------------------------
-- 等待节点
-- 从ai开始执行到该节点开始，到结束时间都为running，在等待时间结束后，节点状态改为success
-- 只会返回成功或运行中
oo.class("WaitNode","BehaviourNode")
function WaitNode:__init(time)
	BehaviourNode.__init(self)
	self._kind = "WaitNode"
	self._waitTime = time   --等待时间间隔(ms)
	self._wakeTime = nil    --唤醒时间
end

function WaitNode:toString()
	local w = self._wakeTime - env.unixtimeMs()
	return string.format("%.f",w)
end

function WaitNode:visit()
	local ctm = env.unixtimeMs()
	if self._status~=BT.RUNNING then
		self._wakeTime = ctm + self._waitTime
		self._status = BT.RUNNING
	end

	if self._status==BT.RUNNING then
		if self._wakeTime>ctm then
			self:sleep(self._wakeTime-ctm)
		else
			self._status = BT.SUCCESS
		end
	end
end

-- loop节点
--[[
逻辑类似序列节点（SequenceNode），会一个接一个执行子节点。
如果子节点的状态为running，则阻止下一个节点的运行，下一次再次执行该节点时，会继续从running的子节点开始；
如果子节点的状态为faile，则将自身设置为failed并返回；
如果循环次数已满，则设置自身状态为success并返回。
--]]
oo.class("LoopNode","BehaviourNode")
function LoopNode:__init(children,maxreps,maxrepFn)
	BehaviourNode.__init(self,children)
	self._kind = "LoopNode"
	self._idx = 1					--执行到第几个子节点了
	self._maxreps = maxreps or 0 	--最大循环次数
	self._rep = 0					--当前循环到第几次了
	self._fn = maxrepFn				--用来动态设置最大循环次数
end

function LoopNode:toString()
	return tostring(self._idx)
end

function LoopNode:reset()
	BehaviourNode.reset(self)
	self._idx = 1
	self._rep = 0
end

function LoopNode:visit()
	if self._status ~= BT.RUNNING then --如果执行该节点时，不为running则重置
		self._idx = 1
		self._rep = 0
		self._status = BT.RUNNING
		if self._fn then
			local n = self._fn(self)
			if n and type(n) =="number" then
				self._maxreps = math.floor(n)
			else
				self._maxreps = 0
			end
		end
	end

	-- 直接返回成功
	if self._maxreps<=0 then
		self._status = BT.SUCCESS
		return
	end

	local done = false
	local count = #self._children
	local childStatus
	while self._idx <= count do
		local child = self._children[self._idx]
		child:visit()
		childStatus = child._status
		if childStatus == BT.RUNNING or childStatus == BT.FAILED then
			self._status = childStatus
			return
		end

		self._idx = self._idx + 1
	end

	self._idx = 1               --一次loop完毕
	self._rep = self._rep + 1   --loop次数+1
	if self._rep >= self._maxreps then
		self._status = BT.SUCCESS
	else
		for k,v in ipairs(self._children) do
			v:reset()
		end
	end
end

------------------------------------- 优先级节点 -------------------------------------
-- 优先级节点（等价于：优先选择节点）
-- 顺序执行子节点，如果子节点返回成功或运行中，记录该子节点，并将其他子节点重置
oo.class("PriorityNode","BehaviourNode")
function PriorityNode:__init(children,period)
	BehaviourNode.__init(self,children)
	self._kind = "PriorityNode"
	self._period = period or 10  	--行为树执行的周期(毫秒级，10的倍数)
	self._lastTime = 0          	--上一次执行的时间
	self._idx = nil             	--执行到哪个子节点了
	self._doEval = false
end

function PriorityNode:toString()
	local time_till = 0
	if self._period then
		time_till = (self._lastTime or 0) + self._period - env.unixtimeMs()
	end

	return string.format("idx=%d,eval=%d", self._idx or -1, time_till)
end

function PriorityNode:getSleepTime()
	if not self._period then
		return 0
	end

	local timeTo = 0 --到期时间
	if self._lastTime then
		timeTo = (self._lastTime + self._period) - env.unixtimeMs()
		if timeTo < 0 then
			timeTo = 0
		end
	end

	-- if self._status == BT.RUNNING then
	-- 	return timeTo
	-- elseif self._status == BT.READY then
	-- 	return self._period
	-- end
	if self._status then
		return timeTo
	end

	return nil
end

function PriorityNode:reset()
	BehaviourNode.reset(self)
	self._idx = nil
end

-- self._lastTime 如果为nil，则表示重新开始执行该节点
function PriorityNode:visit()
	local ctm = env.unixtimeMs()
	local do_eval = not self._lastTime or self._lastTime + self._period < ctm

	self._doEval = do_eval
	if do_eval then --从头开始评估(执行)子节点（这里相当于定时器，每隔self._period就执行一次）
		--print("------------->do_eval")
		local old_event = nil --子节点是否是eventnode
		local eventChild = self._idx and self._children[self._idx]
		if eventChild and eventChild:iskindof("EventNode") then
			old_event = eventChild
		end

		self._lastTime = ctm --最后一次从头执行的时间戳

		local found = false --找到第一个返回成功或运行中的子节点
		for idx, child in ipairs(self._children) do
			-- 如果处于运行中的节点是EventNode，并且child也是EventNode，并且child的优先级比old_event大
			local should_test_anyway = old_event and child:iskindof("EventNode") and old_event.priority <= child.priority
			if not found or should_test_anyway then
				if child._status == BT.FAILED or child._status == BT.SUCCESS then
					child:reset()
				end

				child:visit()
				local cs = child._status
				if cs == BT.SUCCESS or cs == BT.RUNNING then
					if should_test_anyway and self._idx ~= idx then
						self._children[self._idx]:reset()
					end
					found = true
					self._status = cs
					self._idx = idx
				end
			else
				child:reset()
			end
		end
		if not found then
			self._status = BT.FAILED
		end
	else
		if self._idx then
			local child = self._children[self._idx]
			if child._status == BT.RUNNING then
				child:visit()
				self._status = child._status
				if self._status ~= BT.RUNNING then
					self._lastTime = nil
				end
			end
		end
	end
end

------------------------------------- 事件节点 -------------------------------------
-- 一个事件只能包含一个子节点，即触发事件后，只能做一件事情
oo.class("EventNode","BehaviourNode")
function EventNode:__init(event, child, priority)
	assert(event)
	BehaviourNode.__init(self, {child}, true)
	self._event = event
	self._priority = priority or 0	--优先级
	self._triggered = false 		--事件是否触发
	self._data = nil
	self._kind = "EventNode"
end

function EventNode:onSetBrain()
	if self._event then
		local owner = self:getOwner()
		if owner then
			owner:addEventListener(self, self._event, "onEvent")
		end
	end
end

function EventNode:onStop()
	if self._event then
		local owner = self:getOwner()
		if owner then
			owner:removeEventListener(self)
		end
	end
end

function EventNode:onEvent(data)
	if self._status == BT.RUNNING then
		self._children[1]:reset()
	end

	self._triggered = true
	self._data = data

	-- 强制tick一次大脑
	if self._brain then
		--wake the parent!
		self:doToParents(function(node)
			if node:iskindof("PriorityNode") then
				node._lastTime = nil --让PriorityNode从头执行
			end
		end)

		self._brain:forceUpdate()
	end
end

function EventNode:step()
	BehaviourNode.step(self)
	self._triggered = false
end

function EventNode:reset()
	BehaviourNode.reset(self)
	self._triggered = false
end

function EventNode:visit()
	if self._status == BT.READY and self._triggered then
		self._status = BT.RUNNING
	end

	if self._status == BT.RUNNING then
		if self._children and #self._children == 1 then
			local child = self._children[1]
			child:visit()
			self._status = child._status
		else
			self._status = BT.FAILED
		end
	end
end