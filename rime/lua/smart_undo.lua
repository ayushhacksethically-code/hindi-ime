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

local function smart_undo_impl(key_event, env)
    local engine = env.engine
    local context = engine.context

    -- Ignore key release events
    if key_event:release() then
        return kNoop
    end

    -- Ignore if modifier keys (Ctrl, Alt, Super) are active
    if key_event:ctrl() or key_event:alt() or key_event:super() then
        if env.can_undo then
            env.can_undo = false
            env.last_raw = nil
            env.last_cand = nil
        end
        return kNoop
    end

    local key_name = key_event:repr()

    -- 1. Space press on active candidate menu:
    -- Commit candidate + trailing space atomically, and remember the original Roman input.
    if key_name == "space" and context:has_menu() then
        local cand = context:get_selected_candidate()
        if cand then
            env.last_raw = context.input
            env.last_cand = cand.text
            env.can_undo = true

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

        if raw and #raw > 0 then
            -- Attempt to reopen previous selection to retract committed text if engine supports it
            local reopened = false
            if context.reopen_previous_selection then
                reopened = pcall(function() return context:reopen_previous_selection() end)
            end

            -- Fallback / Preedit restoration: put the raw English spelling back into input
            if not reopened or context.input == "" then
                context.input = raw
            end
            return kAccepted
        end
    end

    -- 3. Any other key resets the undo window
    if env.can_undo and key_name ~= "space" then
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
        return kNoop
    end
end

return smart_undo
