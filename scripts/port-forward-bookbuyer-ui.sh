#!/bin/bash

# This script port forwards from the BOOKBUYER pod to local port 8080

BOOKBUYER_LOCAL_PORT="${BOOKBUYER_LOCAL_PORT:-8080}"
POD="$(kubectl get pods --selector app=bookbuyer -n bookbuyer --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward "$POD" -n bookbuyer "$BOOKBUYER_LOCAL_PORT":14001
