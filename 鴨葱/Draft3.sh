#!/usr/bin/env python3
"""
鴨葱うどん調理支援スクリプト

音声読み上げとタイマー機能付きの対話型レシピアプリケーション
"""
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional, Tuple

import pyttsx3


class CookingStep(Enum):
    """調理ステップの列挙型"""
    BOIL_BROTH = 0
    ADD_UDON = 1
    ADD_INGREDIENTS = 2
    SERVE = 3


@dataclass
class Ingredient:
    """食材クラス"""
    name: str
    quantity: str
    
    def parse_quantity(self) -> Tuple[Optional[int], str]:
        """
        分量を数値と単位に分離
        
        Returns:
            (数値, 単位)のタプル。数値がない場合はNone
        """
        numbers = re.findall(r'\d+', self.quantity)
        unit = re.sub(r'\d+', '', self.quantity)
        
        if numbers:
            return int(numbers[0]), unit
        return None, self.quantity
    
    def adjust(self, multiplier: int) -> 'Ingredient':
        """
        分量を調整
        
        Args:
            multiplier: 倍率
            
        Returns:
            調整後の食材インスタンス
        """
        num, unit = self.parse_quantity()
        
        if num is not None:
            adjusted_quantity = f"{num * multiplier}{unit}"
        else:
            adjusted_quantity = f"{multiplier}{self.quantity}"
        
        return Ingredient(self.name, adjusted_quantity)


@dataclass
class Recipe:
    """レシピクラス"""
    name: str
    ingredients: List[Ingredient]
    steps: List[str]
    cooking_times: Dict[CookingStep, int] = field(default_factory=dict)
    
    def get_adjusted_ingredients(self, servings: int) -> List[Ingredient]:
        """
        人数分に調整した材料を取得
        
        Args:
            servings: 人数
            
        Returns:
            調整後の材料リスト
        """
        return [ingredient.adjust(servings) for ingredient in self.ingredients]
    
    def display_ingredients(self, servings: int) -> None:
        """
        材料を表示
        
        Args:
            servings: 人数
        """
        print(f"\n■ 材料（{servings}人分）")
        adjusted = self.get_adjusted_ingredients(servings)
        
        for ingredient in adjusted:
            print(f"・{ingredient.name}: {ingredient.quantity}")
    
    def display_steps(self) -> None:
        """調理手順を表示"""
        print("\n■ 調理手順")
        for i, step in enumerate(self.steps, 1):
            print(f"{i}. {step}")


class Stopwatch:
    """ストップウォッチクラス"""
    
    def __init__(self):
        self._start_time: Optional[datetime] = None
        self._elapsed_time: float = 0.0
    
    @property
    def is_running(self) -> bool:
        """実行中かどうか"""
        return self._start_time is not None
    
    @property
    def elapsed_time(self) -> float:
        """経過時間（秒）"""
        if self.is_running:
            return (datetime.now() - self._start_time).total_seconds()
        return self._elapsed_time
    
    def start(self) -> None:
        """計測開始"""
        if not self.is_running:
            self._start_time = datetime.now()
    
    def stop(self) -> float:
        """
        計測停止
        
        Returns:
            経過時間（秒）
        """
        if self.is_running:
            self._elapsed_time = (datetime.now() - self._start_time).total_seconds()
            self._start_time = None
        
        return self._elapsed_time
    
    def reset(self) -> None:
        """リセット"""
        self._start_time = None
        self._elapsed_time = 0.0


class TextToSpeech:
    """音声読み上げクラス"""
    
    def __init__(self, enabled: bool = True):
        """
        音声読み上げを初期化
        
        Args:
            enabled: 音声読み上げを有効にするか
        """
        self.enabled = enabled
        self._engine: Optional[pyttsx3.Engine] = None
        
        if enabled:
            self._initialize_engine()
    
    def _initialize_engine(self) -> None:
        """音声エンジンを初期化"""
        try:
            self._engine = pyttsx3.init()
            print("音声読み上げが有効です")
        except Exception as e:
            print(f"警告: 音声エンジンの初期化に失敗しました: {e}")
            print("音声読み上げは無効になります")
            self.enabled = False
            self._engine = None
    
    def speak(self, text: str) -> None:
        """
        テキストを読み上げ
        
        Args:
            text: 読み上げるテキスト
        """
        if not self.enabled or self._engine is None:
            return
        
        try:
            self._engine.say(text)
            self._engine.runAndWait()
        except Exception as e:
            print(f"警告: 音声読み上げに失敗しました: {e}")
    
    def __del__(self):
        """デストラクタ"""
        if self._engine is not None:
            try:
                self._engine.stop()
            except Exception:
                pass


class UserInput:
    """ユーザー入力処理クラス"""
    
    @staticmethod
    def get_servings(min_servings: int = 1, max_servings: int = 10) -> int:
        """
        人数を入力
        
        Args:
            min_servings: 最小人数
            max_servings: 最大人数
            
        Returns:
            入力された人数
        """
        while True:
            try:
                prompt = f"何人分作りますか？({min_servings}-{max_servings}): "
                servings = int(input(prompt))
                
                if min_servings <= servings <= max_servings:
                    return servings
                
                print(f"{min_servings}から{max_servings}の間で入力してください。")
                
            except ValueError:
                print("正しい数字を入力してください。")
            except EOFError:
                print("\n入力が中断されました。")
                sys.exit(1)
    
    @staticmethod
    def confirm(message: str) -> bool:
        """
        確認メッセージを表示
        
        Args:
            message: 確認メッセージ
            
        Returns:
            Yesの場合True
        """
        while True:
            try:
                response = input(f"{message} (y/n): ").lower().strip()
                
                if response in ('y', 'yes'):
                    return True
                elif response in ('n', 'no'):
                    return False
                
                print("'y'または'n'を入力してください。")
                
            except EOFError:
                return False


class CookingSession:
    """調理セッションクラス"""
    
    def __init__(self, recipe: Recipe, servings: int, tts: TextToSpeech):
        """
        調理セッションを初期化
        
        Args:
            recipe: レシピ
            servings: 人数
            tts: 音声読み上げ
        """
        self.recipe = recipe
        self.servings = servings
        self.tts = tts
        self.timer = Stopwatch()
    
    def display_introduction(self) -> None:
        """調理の導入を表示"""
        print(f"\n{'='*50}")
        print(f"{self.recipe.name}の作り方")
        print(f"{'='*50}")
        
        self.recipe.display_ingredients(self.servings)
        self.recipe.display_steps()
        print()
    
    def start(self) -> None:
        """調理を開始"""
        self.display_introduction()
        
        start_message = f"{self.recipe.name}の調理を始めます。"
        print(start_message)
        self.tts.speak(start_message)
        
        print("\n■ 調理を開始")
        
        for i, step in enumerate(self.recipe.steps):
            self._execute_step(i, step)
        
        self._finish()
    
    def _execute_step(self, step_index: int, step_text: str) -> None:
        """
        調理ステップを実行
        
        Args:
            step_index: ステップのインデックス
            step_text: ステップの説明
        """
        print(f"\n【手順 {step_index + 1}】")
        print(step_text)
        self.tts.speak(step_text)
        
        # タイマー開始
        self.timer.start()
        
        # 調理時間を取得
        cooking_step = CookingStep(step_index)
        cooking_time = self.recipe.cooking_times.get(cooking_step, 10)
        
        # 待機
        self._wait_with_progress(cooking_time)
        
        # タイマー停止
        elapsed = self.timer.stop()
        print(f"✓ 完了（経過時間: {elapsed:.1f}秒）")
        
        self.timer.reset()
    
    def _wait_with_progress(self, duration: int) -> None:
        """
        進捗を表示しながら待機
        
        Args:
            duration: 待機時間（秒）
        """
        print(f"調理中... ({duration}秒)", end="", flush=True)
        
        for _ in range(duration):
            time.sleep(1)
            print(".", end="", flush=True)
        
        print()
    
    def _finish(self) -> None:
        """調理を完了"""
        print(f"\n{'='*50}")
        print("✓ 調理完了！")
        print(f"{'='*50}")
        
        completion_message = f"{self.recipe.name}の完成です。召し上がれ。"
        self.tts.speak(completion_message)


class Application:
    """メインアプリケーションクラス"""
    
    # デフォルトレシピの定義
    DEFAULT_RECIPE = Recipe(
        name="鴨葱うどん",
        ingredients=[
            Ingredient("うどん", "1玉"),
            Ingredient("鴨肉", "50g"),
            Ingredient("九条ネギ", "1本"),
            Ingredient("だし汁", "300ml"),
        ],
        steps=[
            "鍋にだし汁を入れて沸騰させる。",
            "うどんを袋から取り出し、鍋に入れる。",
            "うどんが柔らかくなったら、鴨肉と九条ネギを加える。",
            "温まったら、器に盛り付けて完成。"
        ],
        cooking_times={
            CookingStep.BOIL_BROTH: 30,
            CookingStep.ADD_UDON: 30,
            CookingStep.ADD_INGREDIENTS: 30,
            CookingStep.SERVE: 10,
        }
    )
    
    def __init__(self, enable_tts: bool = True):
        """
        アプリケーションを初期化
        
        Args:
            enable_tts: 音声読み上げを有効にするか
        """
        self.recipe = self.DEFAULT_RECIPE
        self.tts = TextToSpeech(enabled=enable_tts)
    
    def run(self) -> None:
        """アプリケーションを実行"""
        try:
            print(f"『{self.recipe.name}』調理支援プログラム")
            print("-" * 50)
            
            # 人数入力
            servings = UserInput.get_servings()
            
            # 調理セッション開始
            session = CookingSession(self.recipe, servings, self.tts)
            session.start()
            
        except KeyboardInterrupt:
            self._handle_interruption()
    
    def _handle_interruption(self) -> None:
        """中断処理"""
        print("\n\n調理を中断しました。")
        self.tts.speak("調理を中断しました。")


def main() -> None:
    """メイン実行関数"""
    app = Application(enable_tts=True)
    app.run()


if __name__ == "__main__":
    main()
