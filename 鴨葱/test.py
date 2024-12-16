import unittest
from datetime import datetime
import io
import sys
from contextlib import contextmanager

# メインプログラムのクラスとメソッドをインポート
from kamo_negi_udon import Stopwatch, adjust_ingredients, ingredients

@contextmanager
def capture_output():
    new_out = io.StringIO()
    old_out = sys.stdout
    try:
        sys.stdout = new_out
        yield sys.stdout
    finally:
        sys.stdout = old_out

class TestRecipe(unittest.TestCase):
    def setUp(self):
        self.stopwatch = Stopwatch()

    def test_stopwatch(self):
        """タイマーの動作テスト"""
        self.stopwatch.start()
        # 1秒待機
        import time
        time.sleep(1)
        elapsed = self.stopwatch.stop()
        # 許容誤差0.1秒で1秒経過していることを確認
        self.assertAlmostEqual(elapsed, 1.0, delta=0.1)

    def test_ingredient_adjustment(self):
        """材料の分量調整テスト"""
        # 2人分に調整
        adjusted = adjust_ingredients(2)
        self.assertEqual(adjusted["うどん"], "2玉")
        self.assertEqual(adjusted["鴨肉"], "100g")
        
        # 3人分に調整
        adjusted = adjust_ingredients(3)
        self.assertEqual(adjusted["うどん"], "3玉")
        self.assertEqual(adjusted["鴨肉"], "150g")

    def test_invalid_portions(self):
        """不正な人数入力のテスト"""
        with capture_output() as output:
            try:
                # メインプログラムを実行して、不正な入力をシミュレート
                from unittest.mock import patch
                with patch('builtins.input', return_value='abc'):
                    from kamo_negi_udon import main
                    main()
            except ValueError:
                pass
        
        # エラーメッセージが表示されることを確認
        self.assertIn("正しい数字を入力してください", output.getvalue())

if __name__ == '__main__':
    unittest.main()