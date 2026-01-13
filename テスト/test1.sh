#!/bin/bash

# 問題生成スクリプト
# 様々なカテゴリの日本語問題を自動生成します

# 問題ファイルを保存するディレクトリを作成
mkdir -p generated_quiz/{文法,語彙,読解,論理,数学,文化}

# カテゴリリスト
CATEGORIES=("文法" "語彙" "読解" "論理" "数学" "文化")

# 問題IDの接頭辞を設定
ID_PREFIX="GQ"
CURRENT_ID=1

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

# 文法問題を生成
generate_grammar_question() {
    local question="次の文の空欄に入る最も適切な助詞はどれですか。\n「彼は昨日＿学校に行かなかった。」"
    local options="A. が\nB. を\nC. は\nD. も\nE. に"
    local answer="C"
    local explanation="「は」は主題を表す助詞で、この文脈では主語「彼」に対して最も適切です。"
    
    generate_question "文法" "$question" "$options" "$answer" "$explanation"
}

# 語彙問題を生成
generate_vocabulary_question() {
    local question="次の言葉の意味として最も適切なものはどれですか。\n「頑固」"
    local options="A. 優しくて思いやりがある\nB. 自分の意見や考えを曲げない\nC. 頭の回転が速い\nD. 感情的になりやすい\nE. 何事にも無関心である"
    local answer="B"
    local explanation="「頑固」とは、自分の意見や考えを強く持ち、それを簡単に変えない性質や態度を表す言葉です。"
    
    generate_question "語彙" "$question" "$options" "$answer" "$explanation"
}

# 読解問題を生成
generate_reading_question() {
    local question="次の文章を読んで、問いに答えなさい。\n\n日本の伝統的な庭園は、自然の景観を小さな空間に凝縮して表現することが多い。石や水、植物を使って山や川、海などの自然の要素を象徴的に配置し、観る人に広大な自然を想起させる。これは「縮景」と呼ばれる技法で、限られた空間で無限の広がりを表現する日本庭園の特徴的な手法である。\n\nこの文章によると、日本庭園の「縮景」とは何ですか。"
    local options="A. 庭園を小さく作ること\nB. 自然の要素を象徴的に配置すること\nC. 石や水を使うこと\nD. 観る人に広大な自然を想起させる技法\nE. 無限の広がりを持つ庭園のこと"
    local answer="D"
    local explanation="文章によれば、「縮景」とは自然の景観を小さな空間に凝縮して表現し、観る人に広大な自然を想起させる技法です。"
    
    generate_question "読解" "$question" "$options" "$answer" "$explanation"
}

# 論理問題を生成
generate_logic_question() {
    local question="A、B、C、D、Eの5人が一列に並んでいます。次の条件が分かっています。\n・Aはラインの先頭にいる\n・BはCの隣にいる\n・DはEの前にいる\n・CはAの隣ではない\n\nこのとき、正しいのはどれですか。"
    local options="A. Eは最後尾にいる\nB. BはDの隣にいる\nC. CはEの前にいる\nD. ラインの順番はA-B-C-D-Eである\nE. ラインの順番はA-D-E-B-Cである"
    local answer="A"
    local explanation="AはBかDの隣でないといけません。DはEの前なので、BがAの隣、DがBの隣、EがDの隣、そしてCがEの隣となる配置になります。つまり、A-B-D-E-Cの順番になり、Eは最後尾ではありません。しかし、A-D-B-C-Eの配置でもAはラインの先頭、BはCの隣、DはEの前の条件を満たします。この配置ではEは最後尾です。したがって、「Eは最後尾にいる」が正解です。"
    
    generate_question "論理" "$question" "$options" "$answer" "$explanation"
}

# 全カテゴリの問題を1つずつ生成
generate_grammar_question
generate_vocabulary_question
generate_reading_question
generate_logic_question

echo "基本問題の生成が完了しました。"
