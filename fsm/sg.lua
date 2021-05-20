-- state graph

oo.single("ScanTarge")
function ScanTarge:init()
	self._name = "scan"
	self._frequency = 500 --ms, 0表示瞬时状态，不需要onupdate
end

function ScanTarge:onEnter(obj)
	-- 搜寻目标

	-- 如果目标在技能范围内，则进入攻击状态
	-- 如果不在目标范围，则进入追踪状态
end

oo.single("TraceState")
function TraceState:init()
	self._name = "trace"
end

function TraceState:onEnter(obj, param)
	local lastState
	obj._curState = self._name
	obj:traceTarget()

	-- 设置追踪目标
	-- 持续更新追踪轨迹
end

function TraceState:onUpdate(obj)
	-- body
	-- 500ms更新一次追踪
	-- 如果追踪成功，则进入攻击状态
	-- 如果追踪失败，则进入回家状态
end


oo.single("AttackState")
function AttackState:init()
	self._name = "attack"
end

function AttackState:onEnter(obj, param)
	-- todo
end

function AttackState:onUpdate(obj)
	-- 释放技能
	-- 如果目标死亡，则进入回家状态
	-- 如果目标没有死亡，等待500ms，再次攻击
	-- 如果目标远离，则进入追踪状态
end

oo.single("GoHomeState")
function GoHomeState:init()
	self._name = "gohome"
end

function GoHomeState:onEnter()
	-- 设置回家点
end

function GoHomeState:onUpdate()
	self._name = "gohome"

	-- 如果正在回家路上，则500ms后，再次检查
	-- 如果已回家，则退出状态机
end



local states = {ScanState, TraceState, ...}
function StateGraph:init(obj)
	-- 哪些事件触发状态机
	-- TODO
end

-- 开始执行
function StateGraph:exec(obj)
	-- TODO
end

function StateGraph:update( ... )
	-- body
end