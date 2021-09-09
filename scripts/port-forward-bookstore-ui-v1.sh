#!/bin/bash

# This script forwards BOOKSTORE v1 port 14001 to localhost port 8084.

backend="${1:-bookstore}"

BOOKSTOREv1_LOCAL_PORT="${BOOKSTOREv1_LOCAL_PORT:-8084}"
POD="$(kubectl get pods --selector app="$backend" -n bookstore --no-headers | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward "$POD" -n bookstore "$BOOKSTOREv1_LOCAL_PORT":14001
