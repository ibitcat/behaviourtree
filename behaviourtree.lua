-- 行为树

oo.single("BT")
BT.READY = "READY"		--准备
BT.SUCCESS = "SUCCESS"	--成功
BT.FAILED = "FAILED"	--失败
BT.RUNNING = "RUNNING"	--运行中

-- 行为树
oo.class("BehaviourTree")
function BehaviourTree:__init(brain,root)
	assert(brain)
	assert(root)
	self._brain = brain 		--该行为树的拥有者
	self._root = root 			--行为树根节点
	self._forceupdate = false	--是否强制更新ai

	-- 设置每个行为树节点拥有者
	self._root:setBrain(brain)
end

-- 强制更新行为树
function BehaviourTree:forceUpdate()
	self._forceupdate = true
end

function BehaviourTree:toString()
	local verStr = '\n[' .. Utils.formatTime().."] Think Ver: " .. (self._brain._thinkVersion)..'\n'
	local treeStr = self._root:getTreeString()
	--print("bt root update: ",env.unixtimeMs(), self._root._status, self._root._doEval, self._root._idx)
	print(verStr..treeStr)
end

function BehaviourTree:update()
	self._root:visit()
	--self:toString()
	self._root:saveStatus()
	self._root:step()

	self._forceupdate = false
end

function BehaviourTree:reset()
	self._root:reset()
end

function BehaviourTree:stop()
	self._root:stop()
end

-- 获取整个行为树的睡眠时间 = 所有节点中，最小的那个睡眠时间
-- 如果返回的睡眠时间为空，则该行为树会停止思考，进入休眠状态
-- 如果返回的睡眠时间为0，则表示行为树最终状态不出在运行中，即该行为树本次思考结果要么失败要么成功
function BehaviourTree:getSleepTime()
	if self._forceupdate then
		return 0
	end

	return self._root:getTreeSleepTime()
end