# Releases kill switch after deliberate disconnect.
# Waits first: network menu takes old tunnel down before bringing next one up.
# Needs UNIT and RELEASE_GRACE_SECONDS in environment.

sleep "$RELEASE_GRACE_SECONDS"
tunnel_up && exit 0
systemctl stop "$UNIT"
