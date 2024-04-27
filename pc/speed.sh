#!/bin/bash

# 現在のチャンネルを取得する
current_channel=$(iwlist wlan0 channel | grep "Current Channel" | awk '{print $4}')

# 空いているチャンネルを検索する
channels=$(iwlist wlan0 channel | grep -o -E 'Channel [0-9]+' | awk '{print $2}' | tr '\n' ' ')

# 空いているチャンネルがある場合は、変更する
if [ -n "$channels" ]; then
   for channel in $channels; do
       if [ "$channel" != "$current_channel" ]; then
           iwconfig wlan0 channel $channel
           break
       fi
   done
fi