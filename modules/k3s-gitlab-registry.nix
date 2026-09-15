# The kubelet resolves an image name with the host's resolver,
# and the public record for this one holds the tailnet address of the GitLab proxy.
# Reaching it that way would need a grant from the node's own tag,
# which couples a k3s role to a registry it only happens to share a cluster with,
# and that path runs over a DERP relay besides.
#
# Pods already take the Service instead,
# through the CoreDNS rewrite the GitLab Application installs.
# This is the same redirection for the node's resolver,
# so a pull stays inside the cluster network.
#
# The address is the gitlab Service's ClusterIP, pinned in its manifest against drift.
# nginx answers with the certificate carrying the name either way,
# so the name a client dials is still the name the certificate holds.
{ ... }:
{
  networking.hosts."10.43.180.246" = [
    "gitlab.bjoernblessin.de"
    "gitlab.pidgemail.com"
  ];
}
