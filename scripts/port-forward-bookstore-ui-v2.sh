#!/bin/bash

# This script forwards BOOKSTORE v2 port 14001 to localhost port 8082

backend="${1:-bookstore-v2}"

BOOKSTOREv2_LOCAL_PORT="${BOOKSTOREv2_LOCAL_PORT:-8082}"
POD="$(kubectl get pods --selector app="$backend" -n bookstore --no-headers | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward "$POD" -n bookstore "$BOOKSTOREv2_LOCAL_PORT":14001
