-- 行为树ai

require('svr.m.ai.brain')
require('svr.m.ai.brain_api')
require('svr.m.ai.behaviourtree')
require('svr.m.ai.behaviournode')

-- actions
require('svr.m.ai.actions.move_to')
require('svr.m.ai.actions.patrol_to')
require('svr.m.ai.actions.patrol_fight')
require('svr.m.ai.actions.go_home')
require('svr.m.ai.actions.trace')
require('svr.m.ai.actions.skill_on_target')

-- brains
require('svr.m.ai.brains.brain_monster')
require('svr.m.ai.brains.brain_mirror')