#!/usr/bin/env python3
"""
SaaSアカウント一括作成ツール

APIを使用してSaaSアカウントを一括作成し、結果をCSVに保存する。

Usage:
    python saas_account_creator.py --count 10 --output accounts.csv
    python saas_account_creator.py --input users.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import logging
import os
import sys
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Iterator

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# =============================================================================
# Configuration
# =============================================================================


@dataclass(frozen=True)
class ApiConfig:
    """API設定"""

    base_url: str
    timeout: int = 30
    max_retries: int = 3
    backoff_factor: float = 0.5

    @classmethod
    def from_env(cls) -> ApiConfig:
        """環境変数から設定を読み込み"""
        base_url = os.getenv("SAAS_API_URL")
        if not base_url:
            raise ValueError("環境変数 SAAS_API_URL が設定されていません")

        return cls(
            base_url=base_url,
            timeout=int(os.getenv("SAAS_API_TIMEOUT", "30")),
            max_retries=int(os.getenv("SAAS_API_MAX_RETRIES", "3")),
        )


@dataclass
class ProcessConfig:
    """処理設定"""

    rate_limit_seconds: float = 3.0
    batch_size: int = 100
    output_path: Path = field(default_factory=lambda: Path("saas_accounts.csv"))
    continue_on_error: bool = True


# =============================================================================
# Domain Models
# =============================================================================


class AccountStatus(Enum):
    """アカウント作成ステータス"""

    PENDING = "pending"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class AccountRequest:
    """アカウント作成リクエスト"""

    username: str
    email: str
    password: str

    def __post_init__(self) -> None:
        if not self.username:
            raise ValueError("username は必須です")
        if not self.email or "@" not in self.email:
            raise ValueError("有効な email が必要です")
        if not self.password or len(self.password) < 8:
            raise ValueError("password は8文字以上必要です")


@dataclass
class AccountResult:
    """アカウント作成結果"""

    username: str
    email: str
    status: AccountStatus
    account_id: str | None = None
    error_message: str | None = None
    created_at: str | None = None

    def to_dict(self) -> dict[str, Any]:
        """辞書に変換"""
        return {
            "username": self.username,
            "email": self.email,
            "status": self.status.value,
            "account_id": self.account_id or "",
            "error_message": self.error_message or "",
            "created_at": self.created_at or "",
        }


# =============================================================================
# Security
# =============================================================================


class PasswordHasher(ABC):
    """パスワードハッシャーの基底クラス"""

    @abstractmethod
    def hash(self, password: str) -> str:
        """パスワードをハッシュ化"""


class Sha256Hasher(PasswordHasher):
    """SHA-256ハッシャー（デモ用、本番ではbcrypt等を使用）"""

    def hash(self, password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()


# =============================================================================
# API Client
# =============================================================================


class SaasApiClient:
    """SaaS API クライアント"""

    def __init__(
        self,
        config: ApiConfig,
        hasher: PasswordHasher | None = None,
        logger: logging.Logger | None = None,
    ) -> None:
        self._config = config
        self._hasher = hasher or Sha256Hasher()
        self._logger = logger or logging.getLogger(__name__)
        self._session = self._create_session()

    def _create_session(self) -> requests.Session:
        """リトライ設定付きセッションを作成"""
        session = requests.Session()

        retry_strategy = Retry(
            total=self._config.max_retries,
            backoff_factor=self._config.backoff_factor,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"],
        )

        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)

        return session

    def create_account(self, request: AccountRequest) -> AccountResult:
        """アカウントを作成"""
        payload = {
            "username": request.username,
            "email": request.email,
            "password": self._hasher.hash(request.password),
        }

        try:
            response = self._session.post(
                self._config.base_url,
                json=payload,
                timeout=self._config.timeout,
            )
            response.raise_for_status()

            data = response.json()
            return AccountResult(
                username=request.username,
                email=request.email,
                status=AccountStatus.SUCCESS,
                account_id=data.get("id") or data.get("account_id"),
                created_at=datetime.now().isoformat(),
            )

        except requests.exceptions.HTTPError as e:
            error_msg = self._extract_error_message(e)
            self._logger.warning("HTTP エラー (%s): %s", request.username, error_msg)
            return AccountResult(
                username=request.username,
                email=request.email,
                status=AccountStatus.FAILED,
                error_message=error_msg,
            )

        except requests.exceptions.RequestException as e:
            self._logger.warning("リクエストエラー (%s): %s", request.username, e)
            return AccountResult(
                username=request.username,
                email=request.email,
                status=AccountStatus.FAILED,
                error_message=str(e),
            )

    def _extract_error_message(self, error: requests.exceptions.HTTPError) -> str:
        """HTTPエラーからメッセージを抽出"""
        try:
            data = error.response.json()
            return data.get("message") or data.get("error") or str(error)
        except (ValueError, AttributeError):
            return f"HTTP {error.response.status_code}"

    def close(self) -> None:
        """セッションを閉じる"""
        self._session.close()

    def __enter__(self) -> SaasApiClient:
        return self

    def __exit__(self, *_: Any) -> None:
        self.close()


# =============================================================================
# Account Generator
# =============================================================================


def generate_accounts(count: int, prefix: str = "user") -> Iterator[AccountRequest]:
    """テスト用アカウントを生成"""
    for i in range(count):
        yield AccountRequest(
            username=f"{prefix}{i}",
            email=f"{prefix}{i}@example.com",
            password=f"SecurePass{i}!@#",
        )


def load_accounts_from_csv(path: Path) -> Iterator[AccountRequest]:
    """CSVからアカウント情報を読み込み"""
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            yield AccountRequest(
                username=row["username"],
                email=row["email"],
                password=row["password"],
            )


# =============================================================================
# Processor
# =============================================================================


@dataclass
class ProcessingStats:
    """処理統計"""

    total: int = 0
    success: int = 0
    failed: int = 0
    skipped: int = 0

    def __str__(self) -> str:
        success_rate = (self.success / self.total * 100) if self.total > 0 else 0
        return (
            f"合計: {self.total}, 成功: {self.success}, "
            f"失敗: {self.failed}, スキップ: {self.skipped}, "
            f"成功率: {success_rate:.1f}%"
        )


class AccountProcessor:
    """アカウント一括作成プロセッサー"""

    def __init__(
        self,
        client: SaasApiClient,
        config: ProcessConfig,
        logger: logging.Logger | None = None,
    ) -> None:
        self._client = client
        self._config = config
        self._logger = logger or logging.getLogger(__name__)
        self._results: list[AccountResult] = []
        self._stats = ProcessingStats()

    def process(self, requests: Iterator[AccountRequest]) -> ProcessingStats:
        """アカウントを一括作成"""
        request_list = list(requests)
        total = len(request_list)
        self._stats.total = total

        self._logger.info("アカウント作成開始: %d 件", total)

        for i, request in enumerate(request_list, 1):
            self._process_single(request, i, total)

            # レート制限
            if i < total:
                time.sleep(self._config.rate_limit_seconds)

        self._logger.info("処理完了: %s", self._stats)
        return self._stats

    def _process_single(
        self,
        request: AccountRequest,
        current: int,
        total: int,
    ) -> None:
        """単一アカウントを処理"""
        self._logger.info(
            "処理中 [%d/%d]: %s",
            current,
            total,
            request.username,
        )

        try:
            result = self._client.create_account(request)
            self._results.append(result)
            self._update_stats(result.status)

            if result.status == AccountStatus.SUCCESS:
                self._logger.info("✓ 作成成功: %s", request.username)
            else:
                self._logger.warning(
                    "✗ 作成失敗: %s - %s",
                    request.username,
                    result.error_message,
                )

        except Exception as e:
            self._logger.error("予期しないエラー (%s): %s", request.username, e)
            self._results.append(
                AccountResult(
                    username=request.username,
                    email=request.email,
                    status=AccountStatus.FAILED,
                    error_message=str(e),
                )
            )
            self._stats.failed += 1

            if not self._config.continue_on_error:
                raise

    def _update_stats(self, status: AccountStatus) -> None:
        """統計を更新"""
        if status == AccountStatus.SUCCESS:
            self._stats.success += 1
        elif status == AccountStatus.FAILED:
            self._stats.failed += 1
        elif status == AccountStatus.SKIPPED:
            self._stats.skipped += 1

    def save_results(self, path: Path | None = None) -> Path:
        """結果をCSVに保存"""
        output_path = path or self._config.output_path

        with open(output_path, "w", newline="", encoding="utf-8") as f:
            if not self._results:
                return output_path

            fieldnames = list(self._results[0].to_dict().keys())
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(r.to_dict() for r in self._results)

        self._logger.info("結果を保存: %s", output_path)
        return output_path

    @property
    def results(self) -> list[AccountResult]:
        return self._results.copy()


# =============================================================================
# Logging Setup
# =============================================================================


def setup_logging(verbose: bool = False) -> logging.Logger:
    """ロガーをセットアップ"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    return logging.getLogger(__name__)


# =============================================================================
# CLI
# =============================================================================


def parse_args() -> argparse.Namespace:
    """コマンドライン引数をパース"""
    parser = argparse.ArgumentParser(
        description="SaaSアカウント一括作成ツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument(
        "--count", "-n",
        type=int,
        help="生成するアカウント数",
    )
    source_group.add_argument(
        "--input", "-i",
        type=Path,
        help="アカウント情報のCSVファイル",
    )

    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=Path("saas_accounts.csv"),
        help="出力CSVファイル (default: saas_accounts.csv)",
    )
    parser.add_argument(
        "--rate-limit",
        type=float,
        default=3.0,
        help="リクエスト間隔（秒） (default: 3.0)",
    )
    parser.add_argument(
        "--prefix",
        default="user",
        help="生成ユーザー名のプレフィックス (default: user)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="詳細ログ出力",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="実際のAPI呼び出しを行わない",
    )

    return parser.parse_args()


def main() -> int:
    """メインエントリーポイント""
    args = parse_args()
    logger = setup_logging(args.verbose)

    try:
        # 設定読み込み
        api_config = ApiConfig.from_env()
        process_config = ProcessConfig(
            rate_limit_seconds=args.rate_limit,
            output_path=args.output,
        )

        # アカウントソース決定
        if args.count:
            accounts = generate_accounts(args.count, args.prefix)
        else:
            if not args.input.exists():
                logger.error("入力ファイルが見つかりません: %s", args.input)
                return 1
            accounts = load_accounts_from_csv(args.input)

        # Dry-runモード
        if args.dry_run:
            logger.info("=== Dry-run モード ===")
            for i, acc in enumerate(accounts, 1):
                logger.info("[%d] %s <%s>", i, acc.username, acc.email)
            return 0

        # 処理実行
        with SaasApiClient(api_config, logger=logger) as client:
            processor = AccountProcessor(client, process_config, logger)
            stats = processor.process(accounts)
            processor.save_results()

        # 結果表示
        print("\n" + "=" * 50)
        print("処理結果")
        print("=" * 50)
        print(stats)
        print(f"出力ファイル: {args.output}")
        print("=" * 50)

        return 0 if stats.failed == 0 else 1

    except ValueError as e:
        logger.error("設定エラー: %s", e)
        return 1
    except KeyboardInterrupt:
        logger.info("中断されました")
        return 130
    except Exception as e:
        logger.exception("予期しないエラー: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
