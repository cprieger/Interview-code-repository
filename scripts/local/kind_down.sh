#!/bin/bash
set -e
kind delete cluster --name weather-sre 2>/dev/null || echo "Cluster already gone."
