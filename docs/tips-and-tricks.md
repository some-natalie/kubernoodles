# Tips and Tricks

## Nested virtualization

Nested virtualization is complicated and has a lot of design tradeoffs.  Each layer has additional overhead and places where things can go wrong.  Some of these could be removed by using a managed Kubernetes provider and not bare metal, but I'm not sure here.

[MTU](https://en.wikipedia.org/wiki/Maximum_transmission_unit) size is important!  Depending on your use of bare metal Kubernetes or a managed cluster provider, the configuration of the entire rest of the network, etc., this can be a common failure point.  In theory, it shouldn't be as much of a problem as it is, since containers should have some level of [Path MTU Discovery](https://en.wikipedia.org/wiki/Path_MTU_Discovery).  The problem with relying on PMTUD is that a _lot_ of corporate network infrastructure will block all/most [ICMP](https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol) messages, resulting in silent networking failures for users.  A fantastic summary of this problem and ways to remediate it are detailed [here](https://blog.cloudflare.com/path-mtu-discovery-in-practice/).

:information_source: This explicitly specifies an MTU of 1450 for the runner pod (Debian/Ubuntu runners) or sets a kernel module flag for MTU probing for the runner pod (RHEL/derivative runners).  The MTU is set to 1400 for any container inside the runner, but your network architects may have better guidance for you.

## Over-provisioning on bare metal

Over-provision (promising more resources than you have available) at your own risk.  This is a rabbit-hole down which there is no end, but you should read and understand the guidance offered by your base hypervisor platform (e.g., vSphere, Hyper-V, etc) first - then look at potentially over-provisioning within Kubernetes.  The Kubernetes scheduler is only as smart as what it can see and depending on your configuration, might not be able to see into the nested solution above it (such as the hypervisor in use or the physical resources of your servers), if that makes sense.

This consideration drove the large difference between the resource requests and limits for the runners.  The quick little tasks that don't require a lot of compute can go anywhere, the heavy usage pods can be moved around on the nodes by the scheduler to optimize longer-running jobs.  If you're using Kubernetes within a VM infrastructure, the worker nodes can be moved around via vMotion as needed to make the best use of the physical compute.  When this goes wrong, it can cause all manner of cryptic error messages so I've made it a habit to always check resource utilization first.

In general, the fewer "layers" you have, the fewer places things can go wrong.
