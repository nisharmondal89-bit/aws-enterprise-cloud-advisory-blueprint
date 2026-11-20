# Runbook: Network Blackholes & EKS Pod Networking Failures

## Scenario A: Service Timeout Reaching DynamoDB/S3 from Isolated Subnets
### Symptoms
* `ConnectTimeoutError` or `ReadTimeoutError` when pods in `isolated_data` subnets invoke AWS APIs.
* VPC Flow Logs show `ACCEPT` on outbound port `443`, followed by zero return packets.

### Root Cause Analysis (RCA)
1. Isolated subnets have no route to a NAT Gateway (`0.0.0.0/0 -> nat-gw`).
2. Either the **Gateway VPC Endpoint** is missing from the subnet's associated Route Table, or a **Network ACL (NACL)** is blocking ephemeral return ports (`1024-65535`).

### Resolution Commands
```bash
# 1. Verify route table prefix list injection for DynamoDB/S3 Gateway Endpoints
aws ec2 describe-route-tables --route-table-ids <rtb-id> \
  --query "RouteTables[].Routes[?starts_with(DestinationPrefixListId, 'pl-')]"

# 2. Trace packet path using AWS VPC Reachability Analyzer
aws ec2 create-network-insights-path \
  --source <eni-id> --destination <vpce-id> --protocol tcp --destination-port 443
```

---

## Scenario B: EKS Pods Stuck in `ContainerCreating` (AWS VPC CNI IP Exhaustion)
### Symptoms
* `kubectl describe pod` reports: `failed to assign an IP address to container`.

### Resolution Commands
```bash
# 1. Inspect available secondary IPs on affected worker nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels."node\.kubernetes\.io/instance-type"

# 2. Enable Prefix Delegation on aws-node DaemonSet to increase max pods per ENI
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
kubectl set env daemonset aws-node -n kube-system WARM_PREFIX_TARGET=1
```

