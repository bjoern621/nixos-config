-- float is a static effect, evaluated only at window creation using initialTitle/initialClass.
-- Bitwarden's initialTitle is "_crx_nngceckbapebfimnlniiiahkandclblb", not "Bitwarden",
-- so matching on title won't work. Must match on class instead.
-- See: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
hl.window_rule({ match = { class = "chrome-nngceckbapebfimnlniiiahkandclblb-Default" }, float = true })
