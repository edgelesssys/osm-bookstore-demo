#!/bin/bash

# This script forwards port 14001 from the BOOKTHIEF pod to local port 8083

BOOKTHIEF_LOCAL_PORT="${BOOKTHIEF_LOCAL_PORT:-8083}"
POD="$(kubectl get pods --selector app=bookthief -n bookthief --no-headers | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward "$POD" -n bookthief "$BOOKTHIEF_LOCAL_PORT":14001
