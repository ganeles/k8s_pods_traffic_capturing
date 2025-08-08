# k8s_pods_traffic_capturing
Here is the script that helps me capture traffic from K8s pods easily.

Sometimes I need to capture traffic from pods (or one pod) where are not tcpdump or tshark.
The way to do it is to add a "sidecar" - anpther container into the same pod.
All the containers in one pod have shared **network** space, so it works as you started tcpdump or tshark inside the same container.
(by the way - this is true for network, but not for disk or process space, so you can't get files from another container in the same pod by default)

I found this article 
https://medium.com/@rakhitharr/debug-network-traffic-in-kubernetes-using-a-sidecar-fd1671d8a35b
and did these actions manually.

But one day I needed to capture the traffic from A LOT of pods at the same time, so I wrote this script to do it automatically.

What this script does:
- It connects to the pods
- Attaches sidecar 
Example of output if you started it without parameters:

```
user@host#./capture_traffic_batch.sh
Usage: ./capture_traffic_batch.sh -n <namespace> -p <pod_prefix> -d <duration_minutes>

  -n     Kubernetes namespace (required)
  -p     Pod name prefix (required)
  -d     Tcpdump duration in minutes (required)

Example:
  ./capture_traffic_batch.sh -n glip-ha-lab -p gas -d 10

Don't forget: you need to be authenticated in advance to run kubectl against your env
```

As result it generates 
