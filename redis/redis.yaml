#!/usr/bin/env python3
"""
Simple Redis Clone Implementation
サポートするコマンド: SET, GET, DEL, EXISTS, EXPIRE, TTL, KEYS, INCR, DECR
"""

import socket
import threading
import time
from typing import Dict, Optional, Any
from datetime import datetime, timedelta


class RedisClone:
    def __init__(self, host: str = '127.0.0.1', port: int = 6380):
        self.host = host
        self.port = port
        self.data: Dict[str, Any] = {}
        self.expiry: Dict[str, float] = {}
        self.lock = threading.Lock()
        self.running = False
        
    def _is_expired(self, key: str) -> bool:
        """キーが期限切れかどうかチェック"""
        if key in self.expiry:
            if time.time() > self.expiry[key]:
                with self.lock:
                    del self.data[key]
                    del self.expiry[key]
                return True
        return False
    
    def set_value(self, key: str, value: str, ex: Optional[int] = None) -> str:
        """SET コマンド"""
        with self.lock:
            self.data[key] = value
            if ex:
                self.expiry[key] = time.time() + ex
            elif key in self.expiry:
                del self.expiry[key]
        return "OK"
    
    def get_value(self, key: str) -> Optional[str]:
        """GET コマンド"""
        if self._is_expired(key):
            return None
        return self.data.get(key)
    
    def delete_key(self, key: str) -> int:
        """DEL コマンド"""
        with self.lock:
            if key in self.data:
                del self.data[key]
                if key in self.expiry:
                    del self.expiry[key]
                return 1
        return 0
    
    def exists(self, key: str) -> int:
        """EXISTS コマンド"""
        if self._is_expired(key):
            return 0
        return 1 if key in self.data else 0
    
    def expire(self, key: str, seconds: int) -> int:
        """EXPIRE コマンド"""
        if key not in self.data or self._is_expired(key):
            return 0
        with self.lock:
            self.expiry[key] = time.time() + seconds
        return 1
    
    def ttl(self, key: str) -> int:
        """TTL コマンド"""
        if key not in self.data:
            return -2
        if self._is_expired(key):
            return -2
        if key not in self.expiry:
            return -1
        remaining = int(self.expiry[key] - time.time())
        return remaining if remaining > 0 else -2
    
    def keys(self, pattern: str = "*") -> list:
        """KEYS コマンド（簡易版）"""
        # 期限切れキーをクリーンアップ
        expired_keys = [k for k in self.data.keys() if self._is_expired(k)]
        
        if pattern == "*":
            return list(self.data.keys())
        
        # 簡単なパターンマッチング
        import re
        regex_pattern = pattern.replace("*", ".*").replace("?", ".")
        return [k for k in self.data.keys() if re.match(regex_pattern, k)]
    
    def incr(self, key: str) -> Optional[int]:
        """INCR コマンド"""
        with self.lock:
            if key not in self.data:
                self.data[key] = "1"
                return 1
            
            try:
                value = int(self.data[key])
                value += 1
                self.data[key] = str(value)
                return value
            except ValueError:
                return None
    
    def decr(self, key: str) -> Optional[int]:
        """DECR コマンド"""
        with self.lock:
            if key not in self.data:
                self.data[key] = "-1"
                return -1
            
            try:
                value = int(self.data[key])
                value -= 1
                self.data[key] = str(value)
                return value
            except ValueError:
                return None
    
    def parse_command(self, command_str: str) -> str:
        """コマンドをパースして実行"""
        parts = command_str.strip().split()
        if not parts:
            return "-ERR empty command\r\n"
        
        cmd = parts[0].upper()
        
        try:
            if cmd == "SET":
                if len(parts) < 3:
                    return "-ERR wrong number of arguments for 'set' command\r\n"
                key, value = parts[1], parts[2]
                ex = None
                if len(parts) >= 5 and parts[3].upper() == "EX":
                    ex = int(parts[4])
                result = self.set_value(key, value, ex)
                return f"+{result}\r\n"
            
            elif cmd == "GET":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'get' command\r\n"
                value = self.get_value(parts[1])
                if value is None:
                    return "$-1\r\n"
                return f"${len(value)}\r\n{value}\r\n"
            
            elif cmd == "DEL":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'del' command\r\n"
                result = self.delete_key(parts[1])
                return f":{result}\r\n"
            
            elif cmd == "EXISTS":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'exists' command\r\n"
                result = self.exists(parts[1])
                return f":{result}\r\n"
            
            elif cmd == "EXPIRE":
                if len(parts) != 3:
                    return "-ERR wrong number of arguments for 'expire' command\r\n"
                result = self.expire(parts[1], int(parts[2]))
                return f":{result}\r\n"
            
            elif cmd == "TTL":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'ttl' command\r\n"
                result = self.ttl(parts[1])
                return f":{result}\r\n"
            
            elif cmd == "KEYS":
                pattern = parts[1] if len(parts) > 1 else "*"
                keys = self.keys(pattern)
                response = f"*{len(keys)}\r\n"
                for key in keys:
                    response += f"${len(key)}\r\n{key}\r\n"
                return response
            
            elif cmd == "INCR":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'incr' command\r\n"
                result = self.incr(parts[1])
                if result is None:
                    return "-ERR value is not an integer\r\n"
                return f":{result}\r\n"
            
            elif cmd == "DECR":
                if len(parts) != 2:
                    return "-ERR wrong number of arguments for 'decr' command\r\n"
                result = self.decr(parts[1])
                if result is None:
                    return "-ERR value is not an integer\r\n"
                return f":{result}\r\n"
            
            elif cmd == "PING":
                return "+PONG\r\n"
            
            elif cmd == "QUIT":
                return "+OK\r\n"
            
            else:
                return f"-ERR unknown command '{cmd}'\r\n"
        
        except Exception as e:
            return f"-ERR {str(e)}\r\n"
    
    def handle_client(self, client_socket: socket.socket, address):
        """クライアント接続を処理"""
        print(f"[+] クライアント接続: {address}")
        
        try:
            while True:
                data = client_socket.recv(1024).decode('utf-8')
                if not data:
                    break
                
                print(f"[>] 受信: {data.strip()}")
                response = self.parse_command(data)
                print(f"[<] 送信: {response.strip()}")
                client_socket.send(response.encode('utf-8'))
                
                if data.strip().upper() == "QUIT":
                    break
        
        except Exception as e:
            print(f"[-] エラー: {e}")
        
        finally:
            client_socket.close()
            print(f"[-] クライアント切断: {address}")
    
    def start(self):
        """サーバー起動"""
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((self.host, self.port))
        server_socket.listen(5)
        
        self.running = True
        print(f"[*] Redis Clone サーバー起動: {self.host}:{self.port}")
        print(f"[*] 接続待機中...")
        
        try:
            while self.running:
                client_socket, address = server_socket.accept()
                client_thread = threading.Thread(
                    target=self.handle_client,
                    args=(client_socket, address)
                )
                client_thread.daemon = True
                client_thread.start()
        
        except KeyboardInterrupt:
            print("\n[*] サーバー停止中...")
        
        finally:
            server_socket.close()
            print("[*] サーバー停止完了")


if __name__ == "__main__":
    redis = RedisClone(host='127.0.0.1', port=6380)
    redis.start()
