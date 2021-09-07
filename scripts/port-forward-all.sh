#!/bin/bash

./scripts/port-forward-bookbuyer-ui.sh &
./scripts/port-forward-bookstore-ui-v1.sh &
./scripts/port-forward-bookstore-ui-v2.sh &
./scripts/port-forward-bookthief-ui.sh &

wait
