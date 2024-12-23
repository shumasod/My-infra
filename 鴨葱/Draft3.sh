import time
import pyttsx3
from datetime import datetime

# 材料
ingredients = {
    "うどん": "1玉",
    "鴨肉": "50g",
    "九条ネギ": "1本",
    "だし汁": "300ml",
}

# 作り方
steps = [
    "鍋にだし汁を入れて沸騰させる。",
    "うどんを袋から取り出し、鍋に入れる。",
    "うどんが柔らかくなったら、鴨肉と九条ネギを加える。",
    "温まったら、器に盛り付けて完成。"
]

# タイマークラス
class Stopwatch:
    def __init__(self):
        self.start_time = None
        self.elapsed_time = 0

    def start(self):
        self.start_time = datetime.now()

    def stop(self):
        if self.start_time:
            end_time = datetime.now()
            self.elapsed_time = (end_time - self.start_time).total_seconds()
            self.start_time = None
        return self.elapsed_time

# 音声読み上げ
def initialize_tts():
    try:
        engine = pyttsx3.init()
        return engine
    except Exception as e:
        print(f"音声エンジンの初期化に失敗しました: {e}")
        return None

def say(engine, text):
    if engine:
        try:
            engine.say(text)
            engine.runAndWait()
        except Exception as e:
            print(f"音声読み上げに失敗しました: {e}")

# 分量調整
def adjust_ingredients(n):
    adjusted = {}
    for ingredient, quantity in ingredients.items():
        # 数値と単位を分離
        num = ''.join(filter(str.isdigit, quantity))
        unit = ''.join(filter(str.isalpha, quantity))
        
        # 数値を調整
        if num:
            adjusted_num = int(num) * n
            adjusted[ingredient] = f"{adjusted_num}{unit}"
        else:
            adjusted[ingredient] = f"{n}{quantity}"
    
    return adjusted

# メイン処理
def main():
    # 音声エンジン初期化
    engine = initialize_tts()
    
    try:
        # 人数入力
        while True:
            try:
                n = int(input("何人分作りますか？(1-10): "))
                if 1 <= n <= 10:
                    break
                print("1から10の間で入力してください。")
            except ValueError:
                print("正しい数字を入力してください。")

        # 分量調整
        adjusted_ingredients = adjust_ingredients(n)
        
        # 材料表示
        print("\n■ 材料（{}人分）".format(n))
        for ingredient, quantity in adjusted_ingredients.items():
            print(f"・{ingredient}: {quantity}")

        # タイマーの初期化
        timer = Stopwatch()
        
        # 音声読み上げ
        say(engine, "鴨葱うどんの作り方を始めます。")
        
        print("\n■ 調理手順")
        # 調理開始
        for i, step in enumerate(steps, 1):
            print(f"\n手順{i}: {step}")
            say(engine, step)

            timer.start()
            
            # 調理時間
            cooking_times = {
                0: 30,  # だし汁を沸騰
                1: 30,  # うどんを茹でる
                2: 30,  # 具材を加える
                3: 10   # 盛り付け
            }
            
            time.sleep(cooking_times[i-1])
            
            elapsed = timer.stop()
            print(f"経過時間: {elapsed:.1f}秒")

        # 完成
        print("\n調理完了！")
        say(engine, "鴨葱うどんの完成です。召し上がれ。")

    except KeyboardInterrupt:
        print("\n\n調理を中断しました。")
        say(engine, "調理を中断しました。")

if __name__ == "__main__":
    main()