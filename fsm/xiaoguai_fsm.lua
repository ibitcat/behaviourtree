-- 小怪
oo.single('FsmXiaoGuaiAction')
FsmXiaoGuaiAction.Scan = 1
FsmXiaoGuaiAction.Trace = 2
FsmXiaoGuaiAction.Attack = 3
FsmXiaoGuaiAction.Gohome = 4

---------------------------- scan ----------------------------
oo.class('FsmAction_xiaoguai_scan', 'FsmAction')
function FsmAction_xiaoguai_scan:__init()
    FsmAction.__init(self, FsmXiaoGuaiAction.Scan)
end

function FsmAction_xiaoguai_scan:run()
end

---------------------------- trace ----------------------------
oo.class('FsmAction_xiaoguai_trace', 'FsmAction')
function FsmAction_xiaoguai_trace:__init()
    FsmAction.__init(self, FsmXiaoGuaiAction.Trace)
end

function FsmAction_xiaoguai_trace:run()
end

---------------------------- attack ----------------------------
oo.class('FsmAction_xiaoguai_attack', 'FsmAction')
function FsmAction_xiaoguai_attack:__init()
    FsmAction.__init(self, FsmXiaoGuaiAction.Attack)
end

function FsmAction_xiaoguai_attack:run()
end

---------------------------- scan ----------------------------
oo.class('FsmAction_xiaoguai_gohome', 'FsmAction')
function FsmAction_xiaoguai_gohome:__init()
    FsmAction.__init(self, FsmXiaoGuaiAction.Gohome)
end

function FsmAction_xiaoguai_gohome:run()
end
