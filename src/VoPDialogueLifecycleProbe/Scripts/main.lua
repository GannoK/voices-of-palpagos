-- Voices of Palpagos - Dialogue Lifecycle Probe 0.3.0
-- Creator: Kyle Gannon
--
-- Purpose:
--   Map deliberate NPC conversation actions to exact, named Blueprint
--   functions and inspect their parameters for speaker and subtitle text.
--
-- Safety constraints:
--   * Does nothing during world loading.
--   * Registers no NotifyOnNewObject listener.
--   * Registers no map, actor, character, timer, polling, Tick, or
--     ExecuteUbergraph hook.
--   * Registers only explicit functions on WBP_TalkWindow_C and WBP_Talk_C,
--     after the user has opened a conversation and pressed F8.
--   * Stores hook IDs and primitive log data only.
--   * Plays no audio and writes no Unreal property or save data.

local MOD_NAME = "VoPDialogueLifecycleProbe"
local MOD_VERSION = "0.3.0"
local PREFIX = string.format("[%s %s]", MOD_NAME, MOD_VERSION)

local ARM_KEY = Key.F8
local MARK_KEY = Key.F9
local DISARM_KEY = Key.F10

local MAX_TOTAL_CALLBACKS = 250
local MAX_LOGS_PER_HOOK = 30
local MAX_ARGUMENT_CHARACTERS = 240

local ACTIONS = {
    "CLOSE-INITIAL-CONVERSATION",
    "OPEN-CONVERSATION-AGAIN",
    "ADVANCE-TO-PAGE-2",
    "ADVANCE-TO-PAGE-3",
    "CLOSE-AFTER-PAGE-3",
    "IMMEDIATE-REOPEN"
}

local HOOKS = {
    {
        category = "lifecycle",
        label = "talk-open",
        path =
            "/Game/Pal/Blueprint/UI/UserInterface/Talk/" ..
            "WBP_Talk.WBP_Talk_C:AnmEvent_Open"
    },
    {
        category = "lifecycle",
        label = "talk-close",
        path =
            "/Game/Pal/Blueprint/UI/UserInterface/Talk/" ..
            "WBP_Talk.WBP_Talk_C:AnmEvent_Close_WithEventDispatcher"
    },
    {
        category = "identity",
        label = "talker-name",
        path =
            "/Game/Pal/Blueprint/UI/UserInterface/Talk/" ..
            "WBP_Talk.WBP_Talk_C:SetTalkerName"
    },
    {
        category = "content",
        label = "main-text",
        path =
            "/Game/Pal/Blueprint/UI/UserInterface/Talk/" ..
            "WBP_Talk.WBP_Talk_C:SetMainText"
    },
    {
        category = "presentation",
        label = "next-arrow",
        path =
            "/Game/Pal/Blueprint/UI/UserInterface/Talk/" ..
            "WBP_Talk.WBP_Talk_C:SetNextArrowVisible"
    },
    {
        category = "lifecycle",
        label = "window-hide",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:SetHide"
    },
    {
        category = "content",
        label = "text-list",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:SetTextList"
    },
    {
        category = "content",
        label = "setup-next-text",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:SetupNextText"
    },
    {
        category = "content",
        label = "setup-next-split",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:SetupNextSplittedText"
    },
    {
        category = "input",
        label = "progress-input",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:OnProgressTextInput"
    },
    {
        category = "input",
        label = "progress-text",
        path =
            "/Game/Pal/Blueprint/UI/TalkWindow/" ..
            "WBP_TalkWindow.WBP_TalkWindow_C:ProgressText"
    }
}

local armed = false
local arm_in_progress = false
local disarm_in_progress = false
local arm_generation = 0
local action_index = 0
local current_phase = "UNARMED"
local callback_total = 0
local callback_counts = {}
local suppression_logged = {}
local registered_hooks = {}

local function log(message)
    print(string.format("%s %s\n", PREFIX, tostring(message)))
end

local function unwrap_remote(value)
    if value == nil then
        return nil
    end

    local ok, unwrapped = pcall(function()
        return value:get()
    end)

    if ok then
        return unwrapped
    end

    return value
end

local function safe_is_valid(object)
    if object == nil then
        return false
    end

    local ok, result = pcall(function()
        return object:IsValid()
    end)

    return ok and result == true
end

local function safe_full_name(object)
    object = unwrap_remote(object)
    if not safe_is_valid(object) then
        return "<non-uobject-or-invalid>"
    end

    local ok, result = pcall(function()
        return object:GetFullName()
    end)

    if ok and result ~= nil then
        return tostring(result)
    end

    return "<name-unavailable>"
end

local function safe_address(object)
    object = unwrap_remote(object)
    if not safe_is_valid(object) then
        return "<non-uobject-or-invalid>"
    end

    local ok, result = pcall(function()
        return object:GetAddress()
    end)

    if ok and result ~= nil then
        local numeric = tonumber(result)
        if numeric ~= nil then
            return string.format("0x%X", numeric)
        end
        return tostring(result)
    end

    return "<address-unavailable>"
end

local function sanitize(value)
    local text = tostring(value)
    text = string.gsub(text, "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    text = string.gsub(text, "|", "\\|")

    if #text > MAX_ARGUMENT_CHARACTERS then
        return string.sub(text, 1, MAX_ARGUMENT_CHARACTERS) .. "...<truncated>"
    end

    return text
end

local function try_text_conversion(value)
    if value == nil then
        return nil
    end

    local methods = {
        "ToString",
        "GetText",
        "GetString"
    }

    for _, method_name in ipairs(methods) do
        local ok, result = pcall(function()
            return value[method_name](value)
        end)

        if ok and result ~= nil then
            local converted = tostring(result)
            if converted ~= "" then
                return converted
            end
        end
    end

    return nil
end

local function describe_argument(value)
    local original_type = type(value)
    local unwrapped = unwrap_remote(value)
    local unwrapped_type = type(unwrapped)

    if unwrapped == nil then
        return string.format(
            "remote_type=%s;value=<nil>",
            original_type
        )
    end

    if unwrapped_type == "string"
        or unwrapped_type == "number"
        or unwrapped_type == "boolean"
    then
        return string.format(
            "remote_type=%s;value_type=%s;value=%s",
            original_type,
            unwrapped_type,
            sanitize(unwrapped)
        )
    end

    local text_value = try_text_conversion(unwrapped)
    if text_value ~= nil then
        return string.format(
            "remote_type=%s;value_type=%s;text=%s",
            original_type,
            unwrapped_type,
            sanitize(text_value)
        )
    end

    if safe_is_valid(unwrapped) then
        return string.format(
            "remote_type=%s;value_type=%s;object=%s",
            original_type,
            unwrapped_type,
            sanitize(safe_full_name(unwrapped))
        )
    end

    local ok, fallback = pcall(function()
        return tostring(unwrapped)
    end)

    if ok then
        return string.format(
            "remote_type=%s;value_type=%s;raw=%s",
            original_type,
            unwrapped_type,
            sanitize(fallback)
        )
    end

    return string.format(
        "remote_type=%s;value_type=%s;raw=<unavailable>",
        original_type,
        unwrapped_type
    )
end

local function describe_arguments(...)
    local count = select("#", ...)
    if count == 0 then
        return "argc=0"
    end

    local parts = {
        string.format("argc=%d", count)
    }

    for index = 1, count do
        local value = select(index, ...)
        table.insert(parts, string.format(
            "arg%d={%s}",
            index,
            describe_argument(value)
        ))
    end

    return table.concat(parts, " | ")
end

local function trace_callback(spec, context, ...)
    if not armed then
        return
    end

    callback_total = callback_total + 1
    local count = (callback_counts[spec.label] or 0) + 1
    callback_counts[spec.label] = count

    if callback_total > MAX_TOTAL_CALLBACKS then
        if not suppression_logged["TOTAL"] then
            suppression_logged["TOTAL"] = true
            log(string.format(
                "CALLBACK LOGGING SUPPRESSED | reason=total-limit | limit=%d",
                MAX_TOTAL_CALLBACKS
            ))
        end
        return
    end

    if count > MAX_LOGS_PER_HOOK then
        if not suppression_logged[spec.label] then
            suppression_logged[spec.label] = true
            log(string.format(
                "CALLBACK HOOK SUPPRESSED | hook=%s | limit=%d",
                spec.label,
                MAX_LOGS_PER_HOOK
            ))
        end
        return
    end

    local object = unwrap_remote(context)
    local arguments = describe_arguments(...)

    log(string.format(
        "CALLBACK | generation=%d | phase=%s | total=%d | " ..
        "category=%s | hook=%s | hook_count=%d | address=%s | " ..
        "object=%s | %s",
        arm_generation,
        current_phase,
        callback_total,
        spec.category,
        spec.label,
        count,
        safe_address(object),
        sanitize(safe_full_name(object)),
        arguments
    ))
end

local function register_named_hook(spec)
    local ok, pre_id, post_id = pcall(function()
        return RegisterHook(spec.path, function(context, ...)
            local callback_ok, callback_error = pcall(
                trace_callback,
                spec,
                context,
                ...
            )

            if not callback_ok then
                log(string.format(
                    "CALLBACK FAILED SAFELY | hook=%s | error=%s",
                    spec.label,
                    tostring(callback_error)
                ))
            end
        end)
    end)

    if not ok then
        log(string.format(
            "HOOK REGISTRATION FAILED SAFELY | hook=%s | path=%s | error=%s",
            spec.label,
            spec.path,
            tostring(pre_id)
        ))
        return false
    end

    table.insert(registered_hooks, {
        label = spec.label,
        path = spec.path,
        pre_id = pre_id,
        post_id = post_id
    })

    log(string.format(
        "HOOK REGISTERED | category=%s | hook=%s | path=%s | " ..
        "pre_id=%s | post_id=%s",
        spec.category,
        spec.label,
        spec.path,
        tostring(pre_id),
        tostring(post_id)
    ))

    return true
end

local function remove_registered_hooks(reason)
    local removed = 0
    local failed = 0

    for _, hook in ipairs(registered_hooks) do
        local ok, failure = pcall(function()
            UnregisterHook(
                hook.path,
                hook.pre_id,
                hook.post_id
            )
        end)

        if ok then
            removed = removed + 1
            log(string.format(
                "HOOK UNREGISTERED | reason=%s | hook=%s | path=%s",
                reason,
                hook.label,
                hook.path
            ))
        else
            failed = failed + 1
            log(string.format(
                "HOOK UNREGISTER FAILED SAFELY | reason=%s | " ..
                "hook=%s | path=%s | error=%s",
                reason,
                hook.label,
                hook.path,
                tostring(failure)
            ))
        end
    end

    registered_hooks = {}
    return removed, failed
end

local function reset_capture_state()
    action_index = 0
    current_phase = "ARMED-WAITING-FOR-F9"
    callback_total = 0
    callback_counts = {}
    suppression_logged = {}
end

local function arm_probe()
    if arm_in_progress or disarm_in_progress then
        log("F8 ignored because probe state is changing.")
        return
    end

    if armed then
        log("F8 ignored because the probe is already armed. Press F10 to disarm.")
        return
    end

    arm_in_progress = true
    arm_generation = arm_generation + 1
    reset_capture_state()
    registered_hooks = {}

    local ok, failure = pcall(function()
        for _, spec in ipairs(HOOKS) do
            if not register_named_hook(spec) then
                error(string.format(
                    "registration failed for %s",
                    spec.label
                ))
            end
        end

        armed = true
        log(string.format(
            "ARM SUCCESS | generation=%d | hooks=%d | " ..
            "no_tick_hook=true | Press F9 before each documented action.",
            arm_generation,
            #registered_hooks
        ))
    end)

    if not ok then
        log(string.format("ARM REFUSED SAFELY | error=%s", tostring(failure)))
        local removed, failed = remove_registered_hooks("arm-rollback")
        log(string.format(
            "ARM ROLLBACK COMPLETE | removed=%d | failed=%d",
            removed,
            failed
        ))
        armed = false
        current_phase = "UNARMED"
    end

    arm_in_progress = false
end

local function mark_next_action()
    if not armed then
        log(
            "F9 ignored because the probe is not armed. " ..
            "Open dialogue page 1 and press F8."
        )
        return
    end

    if action_index >= #ACTIONS then
        log(
            "F9 ignored because all documented actions are already marked. " ..
            "Press F10 for the summary and cleanup."
        )
        return
    end

    action_index = action_index + 1
    current_phase = string.format(
        "ACTION-%02d-%s",
        action_index,
        ACTIONS[action_index]
    )

    log(string.format(
        "ACTION ARMED | generation=%d | action_index=%d | action=%s | " ..
        "callback_total_before=%d | Perform this action now.",
        arm_generation,
        action_index,
        ACTIONS[action_index],
        callback_total
    ))
end

local function log_summary()
    log(string.format(
        "SUMMARY BEGIN | generation=%d | callbacks=%d | " ..
        "actions_marked=%d | hooks_registered=%d",
        arm_generation,
        callback_total,
        action_index,
        #registered_hooks
    ))

    for index, spec in ipairs(HOOKS) do
        log(string.format(
            "SUMMARY [%02d] | category=%s | hook=%s | count=%d",
            index,
            spec.category,
            spec.label,
            callback_counts[spec.label] or 0
        ))
    end

    log(string.format(
        "SUMMARY END | generation=%d",
        arm_generation
    ))
end

local function disarm_probe()
    if arm_in_progress or disarm_in_progress then
        log("F10 ignored because probe state is changing.")
        return
    end

    if not armed and #registered_hooks == 0 then
        log("F10 ignored because no hooks are armed.")
        return
    end

    disarm_in_progress = true
    log_summary()
    local removed, failed = remove_registered_hooks("manual-f10")

    armed = false
    current_phase = "UNARMED"
    disarm_in_progress = false

    log(string.format(
        "DISARM COMPLETE | removed=%d | failed=%d | " ..
        "safe_to_return_to_title=true",
        removed,
        failed
    ))
end

RegisterKeyBind(ARM_KEY, function()
    log("F8 pressed; scheduling narrow named-function hook arm.")
    ExecuteInGameThread(function()
        arm_probe()
    end)
end)

RegisterKeyBind(MARK_KEY, function()
    log("F9 pressed; scheduling the next documented action marker.")
    ExecuteInGameThread(function()
        mark_next_action()
    end)
end)

RegisterKeyBind(DISARM_KEY, function()
    log("F10 pressed; scheduling summary and hook removal.")
    ExecuteInGameThread(function()
        disarm_probe()
    end)
end)

log(
    "loaded (manual, log-only, named dialogue hooks). " ..
    "No hook is registered until dialogue is open and F8 is pressed. " ..
    "This build contains no Tick or ExecuteUbergraph hook."
)
