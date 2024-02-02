import time
import pyttsx3

# 材料
ingredients = {
    "うどん": 1玉,
    "鴨肉": 50g,
    "九条ネギ": 1本,
    "だし汁": 300ml,
}

# 作り方
steps = [
    "鍋にだし汁を入れて沸騰させる。",
    "うどんを袋から取り出し、鍋に入れる。",
    "うどんが柔らかくなったら、鴨肉と九条ネギを加える。",
    "温まったら、器に盛り付けて完成。"
]

# タイマー
timer = None

# 音声読み上げ
engine = pyttsx3.init()

def say(text):
    engine.say(text)
    engine.runAndWait()

# 分量調整
def adjust_ingredients(n):
    for ingredient, quantity in ingredients.items():
        ingredients[ingredient] = quantity * n

# メイン処理
def main():
    # 人数
    n = int(input("人数を入力してください: "))

    # 分量調整
    adjust_ingredients(n)

    # 音声読み上げ
    say("鴨葱うどんの作り方を始めます。")

    # 調理開始
    for step in steps:
        print(step)
        say(step)

        # タイマー
        if timer is not None:
            timer.start()

        # 調理
        if step == "鍋にだし汁を入れて沸騰させる。":
            time.sleep(30)
        elif step == "うどんを袋から取り出し、鍋に入れる。":
            time.sleep(30)
        elif step == "うどんが柔らかくなったら、鴨肉と九条ネギを加える。":
            time.sleep(30)
        elif step == "温まったら、器に盛り付けて完成。":
            time.sleep(10)

        # タイマー
        if timer is not None:
            timer.stop()
            print(f"所要時間: {timer.elapsed_time:.2f}秒")

    # 音声読み上げ
    say("鴨葱うどんの完成です。")

# 起動
if __name__ == "__main__":
    # タイマー
    timer = Stopwatch()

    #
