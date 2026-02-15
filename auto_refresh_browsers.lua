obs = obslua

-- 全局变量
local timer_interval_ms = 10000
local is_loop_mode = false
local source_id_filter = "browser_source"
local startup_delay_ms = 15000          -- 默认延迟 15 秒
local startup_refresh_timer_active = false

-- 脚本描述
function script_description()
    return [[
OBS 浏览器源自动刷新工具
- 支持启动后延迟刷新（可设置秒数）
- 支持循环/手动/启动时刷新
    ]]
end

-- 设置界面
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int(props, "interval_seconds", "刷新间隔 (秒)", 1, 3600, 1)
    obs.obs_properties_add_bool(props, "loop_mode", "启用循环刷新")
    obs.obs_properties_add_bool(props, "refresh_on_load", "脚本加载时立即刷新")
    obs.obs_properties_add_int(props, "startup_delay_seconds", "启动后延迟刷新 (秒)", 0, 300, 1)
    obs.obs_properties_add_button(props, "refresh_now", "立即手动刷新所有", manual_refresh)
    return props
end

-- 默认值
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "interval_seconds", 10)
    obs.obs_data_set_default_bool(settings, "loop_mode", false)
    obs.obs_data_set_default_bool(settings, "refresh_on_load", true)
    obs.obs_data_set_default_int(settings, "startup_delay_seconds", 15)
end

-- 设置更新
function script_update(settings)
    local seconds = obs.obs_data_get_int(settings, "interval_seconds")
    is_loop_mode = obs.obs_data_get_bool(settings, "loop_mode")
    local refresh_on_load = obs.obs_data_get_bool(settings, "refresh_on_load")
    local delay_seconds = obs.obs_data_get_int(settings, "startup_delay_seconds")

    timer_interval_ms = seconds * 1000
    startup_delay_ms = delay_seconds * 1000

    -- 清理可能存在的旧定时器
    obs.timer_remove(refresh_callback)
    obs.timer_remove(startup_delayed_refresh)

    startup_refresh_timer_active = false

    print(string.format("[Refresh32] 设置更新：间隔=%d秒, 循环=%s, 加载即刷=%s, 启动延迟=%d秒",
        seconds, tostring(is_loop_mode), tostring(refresh_on_load), delay_seconds))

    -- 优先级：如果勾选了“加载时立即刷新”，则立刻刷新，不走延迟
    if refresh_on_load then
        print("[Refresh32] 加载即刷新 → 立即执行")
        refresh_all_browsers()
    else
        -- 没有勾选立即刷新 → 走启动延迟逻辑
        if startup_delay_ms > 0 then
            print("[Refresh32] 将在 " .. delay_seconds .. " 秒后执行一次启动刷新")
            startup_refresh_timer_active = true
            obs.timer_add(startup_delayed_refresh, startup_delay_ms)
        else
            -- 延迟设为0且没勾立即刷新 → 什么都不做（除非开了循环）
        end
    end

    -- 循环模式独立于启动刷新
    if is_loop_mode then
        obs.timer_add(refresh_callback, timer_interval_ms)
        print(string.format("[Refresh32] 循环刷新已启动，每 %d 秒", seconds))
    end
end

-- 启动后延迟刷新的单次回调
function startup_delayed_refresh()
    if not startup_refresh_timer_active then return end
    startup_refresh_timer_active = false
    print("[Refresh32] 启动延迟时间到 → 执行一次刷新")
    refresh_all_browsers()
    obs.timer_remove(startup_delayed_refresh)
end

-- 循环刷新的回调
function refresh_callback()
    refresh_all_browsers()
    if not is_loop_mode then
        obs.timer_remove(refresh_callback)
    end
end

-- 核心刷新逻辑（基本保持原样）
function refresh_all_browsers()
    print("[Refresh32] >>> 开始强制刷新...")
    local sources = obs.obs_enum_sources()
    if sources == nil then return end

    local count = 0
    for _, source in ipairs(sources) do
        if obs.obs_source_get_id(source) == source_id_filter then
            count = count + 1
            local name = obs.obs_source_get_name(source) or "未知"
            local settings = obs.obs_source_get_settings(source)
            if settings == nil then goto continue end

            local original_url = obs.obs_data_get_string(settings, "url") or ""
            if original_url == "" or original_url == "about:blank" then
                print("[Refresh32] 跳过无效 URL: " .. name)
                goto continue
            end

            -- 防缓存随机参数
            local timestamp = tostring(os.time() * 1000 + math.random(1000))
            local sep = original_url:find("?") and "&" or "?"
            local refresh_url = original_url .. sep .. "_refresh=" .. timestamp

            -- CSS 刷新 trick
            local original_css = obs.obs_data_get_string(settings, "custom_css") or ""
            local new_css = original_css
            if new_css:find("/* AUTO REFRESH DUMMY */") then
                new_css = new_css:gsub("/%* AUTO REFRESH DUMMY %*/.-%}", "")
            end
            new_css = new_css .. "\n/* AUTO REFRESH DUMMY */ body { --refresh-hack: " .. timestamp .. "; }"

            obs.obs_data_set_string(settings, "url", refresh_url)
            obs.obs_data_set_string(settings, "custom_css", new_css)
            obs.obs_source_update(source, settings)

            print("[Refresh32] " .. name .. " 已刷新 → " .. refresh_url)
            obs.obs_data_release(settings)
            ::continue::
        end
    end

    obs.source_list_release(sources)
    print("[Refresh32] <<< 完成，共处理 " .. count .. " 个浏览器源")
end

-- 手动刷新按钮
function manual_refresh(props, prop)
    refresh_all_browsers()
    return true
end

-- 脚本卸载清理
function script_unload()
    obs.timer_remove(refresh_callback)
    obs.timer_remove(startup_delayed_refresh)
end
