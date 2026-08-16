# k3s Cluster Nodes

The hh cluster is one k3s server and one agent on two different networks.
This page covers the machines.
What runs on them, and how a workload asks for one node over the other, is the GitOps repository's business and lives in `hh-cluster-infra`.

| Host | Role | Where | Config |
| --- | --- | --- | --- |
| `vmk3s` | server | libvirt guest on `homelab`, behind the house NAT | [hosts/vmk3s/configuration.nix](../hosts/vmk3s/configuration.nix) |
| `netcup-g12` | agent | netcup VPS, public IPv4 | [hosts/netcup-g12/configuration.nix](../hosts/netcup-g12/configuration.nix) |

## Why the tailnet carries it

The server sits behind NAT with no inbound route, and the agent is on the public internet.
There is no address pair the two reach each other on directly, and forwarding the API port off the house router would put the cluster's front door on the internet.

Tailscale gives each node one address that works from both sides.
[modules/k3s-tailnet.nix](../modules/k3s-tailnet.nix) enables the client, opens the k3s ports on `tailscale0` alone, and turns MagicDNS off.
MagicDNS is off because kubelet writes the `resolv.conf` CoreDNS reads, and a takeover of that file moves every cluster lookup onto `100.100.100.100`.
Peers are therefore addressed by number, out of [lib/tailnet.nix](../lib/tailnet.nix).

Three flags on the server point k3s at those addresses:

- `--node-external-ip` is what flannel builds its tunnel to, given `--flannel-external-ip`.
- `--advertise-address` is what the `kubernetes` Service in every namespace resolves to. Its default is the node's own IP, which for the server is a LAN address a pod on the VPS cannot reach.
- `--tls-san` puts that address in the API server's serving certificate, which an agent dialling it validates.

The server's `--node-ip` stays on the LAN address.
The edge's host ports, the backup pull and a local `kubectl` all find that node there, and moving it would move all three.

## Adding a node

Tailscale assigns an address at first login, so it cannot be written down in advance.
A new node is therefore two rebuilds.

1. Read the join token off the server. It is drawn once at first start and read rather than chosen:

    ```sh
    ssh vmk3s sudo cat /var/lib/rancher/k3s/server/node-token
    ```

    Store it whole, `K10<hash>::server:<password>`. The hash pins the cluster CA, so an agent handed the password alone joins nothing.

    ```sh
    sops --set '["k3s-agent-token"] "<token>"' secrets/k3s-agent.yaml
    ```

    Setting a different token on the *server* is not a rotation.
    Its bootstrap data is encrypted with the token, and a server restarted under another one no longer reads its own cluster.

2. Rebuild the host. Its entry in `lib/tailnet.nix` is still `null`, so this brings up tailscaled and leaves k3s off, and the build says so.

3. Log the node in and read its address back:

    ```sh
    ssh <host> tailscale up
    ssh <host> tailscale ip -4
    ```

    Write the result into `lib/tailnet.nix`. A wrong address shows up as an agent that never registers.

4. Rebuild again, which is what turns k3s on, and confirm from a machine with cluster access:

    ```sh
    kubectl get nodes -o wide
    ```

The server takes the same two rebuilds for its own address, and runs single-node in between.

## Placement

`netcup-g12` carries the taint `node.hh/site=netcup:NoSchedule` and the matching label.
Nothing schedules there that did not ask to.

Storage is what makes the taint necessary rather than merely tidy.
The cluster's only StorageClass is k3s' `local-path`, whose volumes are directories on the node that first bound them.
A pod holding such a PVC that moved to the other node would come up on an empty disk.

A workload opts in with the toleration, and picks the node in particular with a `nodeSelector` on the label.
Both are written in `hh-cluster-infra`, per workload.

## Verify

```sh
ssh netcup-g12 tailscale status
ssh netcup-g12 systemctl status k3s
kubectl get nodes -o wide
kubectl -n observability get pods -o wide
```

A node stuck `NotReady` with the agent running is usually the flannel path: check that UDP 8472 reaches the peer's tailnet address, and that both nodes carry a `--node-external-ip`.
