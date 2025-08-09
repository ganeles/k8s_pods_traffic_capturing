# Kubernetes Pods Traffic Capturing

*[Русская версия / Russian version](README_ru.md)*

A script that helps capture network traffic from Kubernetes pods easily and efficiently.

## Overview

Sometimes you need to capture network traffic from pods where tcpdump or tshark are not installed. The solution is to add a "sidecar" container to the same pod. Since all containers in a pod share the same **network** namespace, the sidecar can capture traffic as if tcpdump was running as a neighboring process.

> **Note**: While containers share network namespace, they don't share disk or process space by default, so you can't access files from other containers in the same pod without additional configuration.

## Background

This script was inspired by [this article](https://medium.com/@rakhitharr/debug-network-traffic-in-kubernetes-using-a-sidecar-fd1671d8a35b). Initially, I performed these actions manually, but when I needed to capture traffic from multiple pods simultaneously, I automated the process with this script.

## How It Works

The script performs the following actions:

1. Connects to the pods, whose name matches the specified prefix
2. Attaches a sidecar container (nicolaka/netshoot)
3. Launches tcpdump in the sidecar container
4. Copies the captured data to the local machine
5. Removes the sidecar container
6. In the process, it writes a log file with all actions performed

## Usage

### Prerequisites

- You must be authenticated with kubectl to access your Kubernetes environment
- The script requires appropriate permissions to create and manage pods in the target namespace

### Command Syntax

```bash
./capture_traffic_batch.sh -n <namespace> -p <pod_prefix> -d <duration_minutes>
```

### Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `-n` | Kubernetes namespace | Yes |
| `-p` | Pod name prefix to match | Yes |
| `-d` | Tcpdump duration in minutes | Yes |

### Example

```bash
./capture_traffic_batch.sh -n MyNamespace -p MyPodName -d 10
```

This command will capture traffic from all pods in the `MyNamespace` namespace that start with `MyPodName` for 10 minutes.

### Help Output

Running the script without parameters shows the usage information:

```bash
user@host:~$ ./capture_traffic_batch.sh
Usage: ./capture_traffic_batch.sh -n <namespace> -p <pod_prefix> -d <duration_minutes>

  -n     Kubernetes namespace (required)
  -p     Pod name prefix (required)
  -d     Tcpdump duration in minutes (required)

Example:
  ./capture_traffic_batch.sh -n MyNamespace -p MyPodName -d 10

Don't forget: you need to be authenticated in advance to run kubectl against your environment
```

## Output

The script generates the following files and directories:

- **Directory**: `./pcaps_<PodName>-<YYYY-MM-DDTHH-MM-SSZ>/` - Contains all captured data
- **Log file**: `./pcaps_<PodName>-<YYYY-MM-DDTHH-MM-SSZ>/pcap-dump.log` - Records all actions performed
- **Capture file**: `./pcaps_<PodName>-<YYYY-MM-DDTHH-MM-SSZ>/<PodName>-<pod-hash>.pcap` - The actual network capture

### Example Output Structure

```
./pcaps_MyPodName-2023-07-11T10-17-17Z/
├── pcap-dump.log
└── MyPodName-79cbffb479-qgwbd.pcap
```

## Features

- **Batch processing**: Capture traffic from multiple pods simultaneously
- **Automated sidecar management**: Automatically attaches and removes sidecar containers
- **Organized output**: Creates timestamped directories for each capture session
- **Comprehensive logging**: Records all actions for troubleshooting and audit purposes
- **Clean cleanup**: Removes temporary sidecar containers after capture completion

## Technical Details

- **Sidecar image**: Uses `nicolaka/netshoot` container for network debugging capabilities
- **Network sharing**: Leverages Kubernetes pod network namespace sharing
- **File format**: Captures are saved in standard pcap format for analysis with Wireshark or other tools

## Troubleshooting

- Ensure you have the necessary RBAC permissions to create pods in the target namespace
- Verify that the pod prefix matches existing pods in the specified namespace
- Check that the `nicolaka/netshoot` image is accessible from your cluster
- Review the generated log files for detailed error information

## TODO

- Add options for filtering captured traffic by ports or IP addresses

## License

This project is provided as-is for educational and operational purposes.
