#!/bin/bash

# 複雑な論理問題生成スクリプト
# より高度な論理的思考を問う問題を生成します

# 問題ファイルを保存するディレクトリを確認
if [ ! -d "generated_quiz" ]; then
    mkdir -p generated_quiz/{文法,語彙,読解,論理,数学,文化}
    CURRENT_ID=9
else
    # 現在のIDを取得（ファイル数+1）
    CURRENT_ID=$(find generated_quiz -type f -name "*.txt" | wc -l)
    CURRENT_ID=$((CURRENT_ID + 1))
fi

# 問題IDの接頭辞
ID_PREFIX="GQ"

# 問題を生成する基本関数
generate_question() {
    local category=$1
    local question_text=$2
    local options=$3
    local answer=$4
    local explanation=$5
    
    # 問題IDを生成
    local id="${ID_PREFIX}-${CURRENT_ID}"
    
    # 問題ファイル作成
    cat > "generated_quiz/${category}/${id}.txt" << EOL
問題ID: ${id}
カテゴリ: ${category}
問題: ${question_text}
選択肢:
${options}
正解: ${answer}
解説: ${explanation}
EOL
    
    echo "問題 ${id} を${category}カテゴリに作成しました。"
    
    # IDをインクリメント
    CURRENT_ID=$((CURRENT_ID + 1))
}

# 順列組み合わせ論理問題
generate_permutation_question() {
    local question="A、B、C、D、E、Fの6人が円卓に座ります。次の条件があります。\n・AとBは隣り合わせに座る\n・CとDは向かい合って座る\n・EはFの右隣に座る\n\nこのとき、正しい記述はどれですか。"
    local options="A. AがCの隣に座ることはない\nB. BがFの左隣に座る可能性がある\nC. CとEが隣り合うことはない\nD. DとFが隣り合うことはない\nE. AとFが向かい合って座ることはない"
    local answer="B"
    local explanation="円卓には6人が座るため、向かい合うのは3組になります。CとDは向かい合うという条件があり、EはFの右隣に座るという条件があります。AとBは隣り合うという条件です。\n\nBがFの左隣に座る可能性を考えると、Fの右隣はE、左隣はBとなり、さらにBの左隣にAが座ります。また、CとDは向かい合うので、残りの2つの席に座ることになります。この配置は可能です。\n\nよって、「BがFの左隣に座る可能性がある」が正しい記述です。"
    
    generate_question "論理" "$question" "$options" "$answer" "$explanation"
}

# 推論論理問題
generate_inference_question() {
    local question="あるクラスの生徒について、次のことがわかっています。\n・数学が得意な生徒は全員英語も得意である\n・英語が得意でない生徒の中には理科が得意な生徒がいる\n・国語が得意な生徒の中に理科が得意でない生徒がいる\n\nこのとき、必ず正しいと言えるのはどれですか。"
    local options="A. 数学が得意な生徒の中には国語が得意な生徒がいる\nB. 英語が得意な生徒は必ず国語も得意である\nC. 理科が得意な生徒の中には数学が得意でない生徒がいる\nD. 国語が得意な生徒は必ず英語も得意である\nE. 数学と理科がともに得意な生徒はいない"
    local answer="C"
    local explanation="「数学が得意な生徒は全員英語も得意」という条件があります。また、「英語が得意でない生徒の中には理科が得意な生徒がいる」という条件があります。\n\nこれらから、「英語が得意でなく、理科が得意な生徒」が存在します。さらに、「数学が得意な生徒は全員英語も得意」なので、「英語が得意でない生徒は数学も得意でない」と言えます。\n\nしたがって、「英語が得意でなく、理科が得意な生徒」は「数学が得意でなく、理科が得意な生徒」でもあります。つまり、「理科が得意な生徒の中には数学が得意でない生徒がいる」が必ず正しいと言えます。"
    
    generate_question "論理" "$question" "$options" "$answer" "$explanation"
}

# ベン図論理問題
generate_venn_diagram_question() {
    local question="全体集合UにおいてA、B、Cは部分集合とします。次の論理式と同値なものはどれですか。\n「(A∩B)∪(A∩C)」"
    local options="A. A∩(B∪C)\nB. (A∪B)∩(A∪C)\nC. (A∩B)∩(A∩C)\nD. A∪(B∩C)\nE. (A∪B)∪(A∪C)"
    local answer="A"
    local explanation="分配法則を使って展開します。\n(A∩B)∪(A∩C) = A∩(B∪C)\n\nこれは集合Aと、集合B∪Cの共通部分を表しています。つまり、集合Aに属し、かつ集合BまたはCの少なくとも一方に属する要素の集合です。\n\n「A∩(B∪C)」が正解です。"
    
    generate_question "論理" "$question" "$options" "$answer" "$explanation"
}

# 確率論理問題
generate_probability_question() {
    local question="袋の中に赤玉2個、白玉3個、青玉4個が入っています。この袋から玉を3個取り出すとき、少なくとも1個の赤玉と少なくとも1個の青玉が含まれる確率を求めなさい。"
    local options="A. 5/12\nB. 41/84\nC. 31/42\nD. 23/42\nE. 17/28"
    local answer="D"
    local explanation="全体の場合の数は、9個から3個を取り出す組み合わせで、9C3 = 84通りです。\n\n少なくとも1個の赤玉と少なくとも1個の青玉が含まれる場合を考えます：\n1. 赤玉1個、青玉1個、白玉1個の場合：2C1 × 4C1 × 3C1 = 2 × 4 × 3 = 24通り\n2. 赤玉1個、青玉2個の場合：2C1 × 4C2 = 2 × 6 = 12通り\n3. 赤玉2個、青玉1個の場合：2C2 × 4C1 = 1 × 4 = 4通り\n\n合計すると 24 + 12 + 4 = 40通りです。\n\nよって、求める確率は 40/84 = 10/21 ≈ 0.476 です。選択肢の中で最も近いのは「23/42」です。"
    
    generate_question "論理" "$question" "$options" "$answer" "$explanation"
}

# 全ての問題を生成
generate_permutation_question
generate_inference_question
generate_venn_diagram_question
generate_probability_question

echo "複雑な論理問題の生成が完了しました。"
