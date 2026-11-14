-- test_smart_undo.lua
-- Unit test for smart_undo Rime Lua processor logic

package.path = package.path .. ";./rime/lua/?.lua;./rime/?.lua"
local smart_undo = require("smart_undo")

local kReject = 0
local kAccepted = 1
local kNoop = 2

-- Mock KeyEvent
local function create_key_event(name, is_release, ctrl, alt, super)
    return {
        repr = function() return name end,
        release = function() return is_release or false end,
        ctrl = function() return ctrl or false end,
        alt = function() return alt or false end,
        super = function() return super or false end
    }
end

-- Mock Candidate
local function create_candidate(text)
    return { text = text }
end

-- Mock Engine & Context
local function create_mock_env(initial_input, candidate_text)
    local committed = {}
    local context = {
        input = initial_input or "",
        _has_menu = (candidate_text ~= nil),
        _candidate = candidate_text and create_candidate(candidate_text) or nil,
        has_menu = function(self) return self._has_menu end,
        get_selected_candidate = function(self) return self._candidate end,
        clear = function(self)
            self.input = ""
            self._has_menu = false
            self._candidate = nil
        end,
        is_composing = function(self) return #self.input > 0 end,
        reopen_previous_selection = function(self) return false end
    }

    local engine = {
        context = context,
        commit_text = function(self, text)
            table.insert(committed, text)
        end
    }

    local env = {
        engine = engine,
        committed = committed
    }
    return env
end

print("=== Running Unit Tests for smart_undo ===")

-- Test Case 1: Space commits candidate + space
do
    local env = create_mock_env("namaste", "नमस्ते")
    local space_key = create_key_event("space")
    local res = smart_undo(space_key, env)

    assert(res == kAccepted, "Test 1 Failed: Space should be accepted")
    assert(#env.committed == 1, "Test 1 Failed: Exactly 1 commit expected")
    assert(env.committed[1] == "नमस्ते ", "Test 1 Failed: Expected 'नमस्ते ', got '" .. tostring(env.committed[1]) .. "'")
    assert(env.can_undo == true, "Test 1 Failed: env.can_undo must be true")
    assert(env.last_raw == "namaste", "Test 1 Failed: env.last_raw must be 'namaste'")
    assert(env.engine.context.input == "", "Test 1 Failed: context.input should be cleared after space commit")
    print("✅ Test 1 Passed: Space successfully commits top candidate with trailing space and arms undo buffer.")

    -- Test Case 2: Immediate BackSpace reverts to original input
    local bs_key = create_key_event("BackSpace")
    local res2 = smart_undo(bs_key, env)

    assert(res2 == kAccepted, "Test 2 Failed: BackSpace should be accepted")
    assert(env.can_undo == false, "Test 2 Failed: env.can_undo must be reset to false")
    assert(env.engine.context.input == "namaste", "Test 2 Failed: context.input should be restored to 'namaste', got: " .. tostring(env.engine.context.input))
    print("✅ Test 2 Passed: Immediate BackSpace intercepts and restores raw Roman input ('namaste').")
end

-- Test Case 3: Key release event is ignored
do
    local env = create_mock_env("namaste", "नमस्ते")
    local space_release = create_key_event("space", true)
    local res = smart_undo(space_release, env)
    assert(res == kNoop, "Test 3 Failed: Release events should return kNoop")
    print("✅ Test 3 Passed: Key release events correctly return kNoop.")
end

-- Test Case 4: Any other key disarms undo
do
    local env = create_mock_env("namaste", "नमस्ते")
    local space_key = create_key_event("space")
    smart_undo(space_key, env)
    assert(env.can_undo == true, "Setup for Test 4 failed")

    local next_char = create_key_event("k")
    local res = smart_undo(next_char, env)
    assert(res == kNoop, "Test 4 Failed: Non-backspace key should return kNoop")
    assert(env.can_undo == false, "Test 4 Failed: Non-backspace key must disarm undo")
    assert(env.last_raw == nil, "Test 4 Failed: last_raw must be cleared")
    print("✅ Test 4 Passed: Subsequent regular keystrokes safely disarm undo state.")
end

-- Test Case 5: Modifier combinations are ignored safely
do
    local env = create_mock_env("namaste", "नमस्ते")
    local ctrl_space = create_key_event("space", false, true)
    local res = smart_undo(ctrl_space, env)
    assert(res == kNoop, "Test 5 Failed: Ctrl+Space should return kNoop")
    print("✅ Test 5 Passed: Modifier combinations (Ctrl+Space) are ignored safely.")
end

print("\n🎉 ALL SMART UNDO TESTS PASSED SUCCESSFULLY!")
