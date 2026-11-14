-- smart_undo.lua
-- Implements "Smart Undo" for Hindi AI Phonetic Engine (Rime Lua Processor)
--
-- Behavior:
-- When a user types a Hinglish word (e.g. "namaste") and presses Space,
-- the top candidate (e.g. "नमस्ते") is committed followed by a space.
-- If the user immediately presses Backspace (without composing another word),
-- this processor intercepts it and reverts to the original Roman text
-- ("namaste") in the composition buffer for immediate correction.

local kReject = 0
local kAccepted = 1
local kNoop = 2

local function log_debug(msg)
    local f = io.open("/tmp/rime_smart_undo.log", "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " [smart_undo] " .. tostring(msg) .. "\n")
        f:close()
    end
end

-- Log when script is initially loaded
log_debug("Script loaded successfully")

local function smart_undo_impl(key_event, env)
    local engine = env.engine
    local context = engine.context

    -- Ignore key release events
    if key_event:release() then
        return kNoop
    end

    local key_name = key_event:repr()

    -- Ignore if modifier keys (Ctrl, Alt, Super) are active
    if key_event:ctrl() or key_event:alt() or key_event:super() then
        if env.can_undo then
            env.can_undo = false
            env.last_raw = nil
            env.last_cand = nil
        end
        return kNoop
    end

    log_debug(string.format("Key: %s | has_menu: %s | composing: %s | can_undo: %s | input: %s",
        tostring(key_name),
        tostring(context:has_menu()),
        tostring(context:is_composing()),
        tostring(env.can_undo),
        tostring(context.input)
    ))

    -- 1. Space press on active candidate menu:
    -- Commit candidate + trailing space atomically, and remember the original Roman input.
    if key_name == "space" and context:has_menu() then
        local cand = context:get_selected_candidate()
        if cand then
            env.last_raw = context.input
            env.last_cand = cand.text
            env.can_undo = true

            log_debug(string.format("Space intercepted on '%s' -> '%s'. Committing with trailing space.", env.last_raw, env.last_cand))
            -- Commit Hindi candidate + space
            engine:commit_text(cand.text .. " ")
            context:clear()
            return kAccepted
        end
    end

    -- 2. Backspace pressed immediately after space-commit:
    if key_name == "BackSpace" and env.can_undo and not context:is_composing() then
        env.can_undo = false
        local raw = env.last_raw
        env.last_raw = nil
        env.last_cand = nil

        log_debug(string.format("BackSpace intercepted! Trying to restore raw input: '%s'", tostring(raw)))

        if raw and #raw > 0 then
            context:push_input(raw)
            log_debug(string.format("After push_input: context.input = '%s'", tostring(context.input)))
            return kAccepted
        end
    end

    -- 3. Any other key resets the undo window
    if env.can_undo and key_name ~= "space" then
        log_debug(string.format("Disarming undo due to key: %s", tostring(key_name)))
        env.can_undo = false
        env.last_raw = nil
        env.last_cand = nil
    end

    return kNoop
end

local function smart_undo(key_event, env)
    local ok, res = pcall(smart_undo_impl, key_event, env)
    if ok then
        return res
    else
        log_debug("ERROR in smart_undo: " .. tostring(res))
        return kNoop
    end
end

return smart_undo
