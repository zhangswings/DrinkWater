#!/bin/bash
cd "$(dirname "$0")"
swift build 2>&1 | tail -3
echo "▶ 启动喝水提醒..."
.build/debug/DrinkWater
