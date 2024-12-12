#!/bin/bash
echo "安全なパスワード: $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)"
