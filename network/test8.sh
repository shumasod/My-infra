#!/bin/bash
read -p "DNSルックアップを行うホスト名を入力してください: " hostname
dig $hostname
