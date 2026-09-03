-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({
    misc = {
        -- Variable Refresh Rate.
        vrr = 1,
        -- Reload on config file change off.
        -- sysconf-reload covers it.
        disable_autoreload = true,
        -- Second launch of single-instance app reaches running process,
        -- which asks to be focused.
        -- Default ignores that ask and only marks window urgent.
        focus_on_activate = true,
    },
})
