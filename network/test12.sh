#!/bin/bash
echo "現在のデフォルトゲートウェイ:"
ip route show default | awk '{print $3}'
