#!/bin/bash
set -euo pipefail

#
# 飲食店紹介ページ生成スクリプト
# 作成日: 2024
# バージョン: 1.1
#
# 概要:
#   一般的な個人飲食店向けのホームページ（HTML/CSS）を生成します
#   店名、住所、電話番号などをコマンドラインオプションでカスタマイズ可能
#
# 使用例:
#   ./generate_site.sh
#   ./generate_site.sh -n "居酒屋 たろう" -p "03-9999-8888"
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.1"
readonly DEFAULT_OUTPUT_DIR="./output"

# ===== グローバル変数（店舗情報のデフォルト値） =====
declare shop_name="小料理屋 和心"
declare shop_name_reading="なごみ"
declare shop_tagline="旬の味を、心を込めて"
declare shop_description="季節の食材を丁寧に仕込み、一品一品心を込めてお作りいたします"
declare shop_address="〒150-0001 東京都渋谷区神宮前1-2-3 和ビル1F"
declare shop_tel="03-1234-5678"
declare shop_owner="山田 太郎"
declare lunch_hours="11:30〜14:00（L.O. 13:30）"
declare dinner_hours="17:30〜22:00（L.O. 21:00）"
declare closed_day="毎週日曜日・祝日"
declare seats="カウンター8席"
declare output_dir="${DEFAULT_OUTPUT_DIR}"

# ===== ヘルパー関数 =====

#
# 使用方法を表示
#
show_usage() {
    cat <<EOF
${C_CYAN}使用方法:${C_RESET} $PROG_NAME [オプション]

飲食店紹介ページ（HTML/CSS）を生成します。

${C_CYAN}オプション:${C_RESET}
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -o, --output <dir>      出力ディレクトリ（デフォルト: ${DEFAULT_OUTPUT_DIR}）
  -n, --name <name>       店名
  -r, --reading <reading> 店名の読み仮名
  -t, --tagline <text>    キャッチコピー
  -a, --address <address> 住所
  -p, --phone <number>    電話番号
  --owner <name>          店主名
  --lunch <hours>         ランチ営業時間
  --dinner <hours>        ディナー営業時間
  --closed <day>          定休日
  --seats <number>        席数

${C_CYAN}例:${C_RESET}
  $PROG_NAME
  $PROG_NAME -n "居酒屋 たろう" -p "03-9999-8888"
  $PROG_NAME -o ./mysite --name "寿司処 まさ" --seats "カウンター10席、テーブル4席×2"

EOF
}

#
# バージョン情報を表示
#
show_version() {
    echo "$PROG_NAME version $VERSION"
}

#
# エラー終了（共通ライブラリを使用）
# 引数: $1=エラーメッセージ
#
show_error_and_exit() {
    log_error "$1"
    echo "詳しい使用方法は「$PROG_NAME --help」を参照してください" >&2
    exit 1
}

# ===== HTML生成関数 =====

generate_html() {
    local output_file="$1"

    cat > "$output_file" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
HTMLEOF

    cat >> "$output_file" <<EOF
    <meta name="description" content="旬の食材を使った心温まる料理をお届けする${shop_name}。落ち着いた雰囲気の中で、季節の味をお楽しみください。">
    <title>${shop_name} | ${shop_tagline}</title>
EOF

    cat >> "$output_file" <<'HTMLEOF'
    <link rel="stylesheet" href="style.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@300;400;500;700&family=Noto+Serif+JP:wght@400;500;700&display=swap" rel="stylesheet">
</head>
<body>
    <!-- ヘッダー -->
    <header class="header">
        <div class="header-inner">
            <h1 class="logo">
HTMLEOF

    cat >> "$output_file" <<EOF
                <a href="#top">${shop_name}</a>
EOF

    cat >> "$output_file" <<'HTMLEOF'
            </h1>
            <nav class="nav">
                <button class="nav-toggle" aria-label="メニューを開く">
                    <span></span>
                    <span></span>
                    <span></span>
                </button>
                <ul class="nav-menu">
                    <li><a href="#concept">コンセプト</a></li>
                    <li><a href="#menu">お品書き</a></li>
                    <li><a href="#gallery">店内風景</a></li>
                    <li><a href="#info">店舗情報</a></li>
                    <li><a href="#access">アクセス</a></li>
                </ul>
            </nav>
        </div>
    </header>

    <!-- ヒーローセクション -->
    <section id="top" class="hero">
        <div class="hero-overlay"></div>
        <div class="hero-content">
HTMLEOF

    cat >> "$output_file" <<EOF
            <p class="hero-subtitle">${shop_tagline}</p>
            <h2 class="hero-title">${shop_name}</h2>
            <p class="hero-description">${shop_description}</p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
            <a href="#info" class="hero-button">ご予約・お問い合わせ</a>
        </div>
        <div class="hero-scroll">
            <span>Scroll</span>
            <div class="scroll-line"></div>
        </div>
    </section>

    <!-- コンセプト -->
    <section id="concept" class="concept section">
        <div class="container">
            <div class="section-header">
                <p class="section-subtitle">Concept</p>
                <h2 class="section-title">当店について</h2>
            </div>
            <div class="concept-content">
                <div class="concept-image">
                    <div class="concept-image-placeholder">
                        <span>店主の写真</span>
                    </div>
                </div>
                <div class="concept-text">
                    <h3>「和の心」を大切に</h3>
                    <p>
                        当店は創業以来、「素材の味を活かす」をモットーに、
                        旬の食材を使った料理をご提供しております。
                    </p>
                    <p>
                        毎朝市場で仕入れる新鮮な魚介、
                        契約農家から届く有機野菜、
                        そして丁寧に取った出汁。
                        日本料理の基本を大切にしながら、
                        お客様に喜んでいただける一皿をお届けいたします。
                    </p>
                    <p>
                        小さなお店ですが、
                        だからこそできる心のこもったおもてなしで、
                        皆様のお越しをお待ちしております。
                    </p>
HTMLEOF

    cat >> "$output_file" <<EOF
                    <p class="concept-signature">店主　${shop_owner}</p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
                </div>
            </div>
        </div>
    </section>

    <!-- お品書き -->
    <section id="menu" class="menu section">
        <div class="container">
            <div class="section-header">
                <p class="section-subtitle">Menu</p>
                <h2 class="section-title">お品書き</h2>
            </div>
            <p class="menu-note">※ 季節により内容が変わります。仕入れ状況によりご提供できない場合がございます。</p>

            <div class="menu-grid">
                <!-- おまかせコース -->
                <div class="menu-category">
                    <h3 class="menu-category-title">おまかせコース</h3>
                    <div class="menu-items">
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">旬彩コース</span>
                                <span class="menu-item-price">¥5,500</span>
                            </div>
                            <p class="menu-item-desc">前菜・お造り・焼物・煮物・食事・デザート（全6品）</p>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">特選コース</span>
                                <span class="menu-item-price">¥8,800</span>
                            </div>
                            <p class="menu-item-desc">前菜・お椀・お造り・焼物・揚物・煮物・食事・デザート（全8品）</p>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">店主おまかせ</span>
                                <span class="menu-item-price">¥12,000</span>
                            </div>
                            <p class="menu-item-desc">その日の最高の食材でお仕立てする特別コース（全10品程度）</p>
                        </div>
                    </div>
                </div>

                <!-- 一品料理 -->
                <div class="menu-category">
                    <h3 class="menu-category-title">一品料理</h3>
                    <div class="menu-items">
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">本日のお造り盛り合わせ</span>
                                <span class="menu-item-price">¥1,800〜</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">だし巻き玉子</span>
                                <span class="menu-item-price">¥800</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">季節の天ぷら</span>
                                <span class="menu-item-price">¥1,200</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">銀鱈の西京焼き</span>
                                <span class="menu-item-price">¥1,500</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">牛すじ煮込み</span>
                                <span class="menu-item-price">¥900</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">〆の土鍋ご飯</span>
                                <span class="menu-item-price">¥1,000</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- お飲み物 -->
                <div class="menu-category">
                    <h3 class="menu-category-title">お飲み物</h3>
                    <div class="menu-items">
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">日本酒（一合）</span>
                                <span class="menu-item-price">¥700〜</span>
                            </div>
                            <p class="menu-item-desc">全国各地の銘酒を取り揃えております</p>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">焼酎（グラス）</span>
                                <span class="menu-item-price">¥600〜</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">生ビール</span>
                                <span class="menu-item-price">¥650</span>
                            </div>
                        </div>
                        <div class="menu-item">
                            <div class="menu-item-header">
                                <span class="menu-item-name">ソフトドリンク各種</span>
                                <span class="menu-item-price">¥400〜</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <p class="menu-tax-note">※ 価格は全て税込みです</p>
        </div>
    </section>

    <!-- ギャラリー -->
    <section id="gallery" class="gallery section">
        <div class="container">
            <div class="section-header">
                <p class="section-subtitle">Gallery</p>
                <h2 class="section-title">店内風景</h2>
            </div>
            <div class="gallery-grid">
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>カウンター席</span></div>
                </div>
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>お造り</span></div>
                </div>
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>日本酒</span></div>
                </div>
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>季節の前菜</span></div>
                </div>
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>店内の様子</span></div>
                </div>
                <div class="gallery-item">
                    <div class="gallery-placeholder"><span>外観</span></div>
                </div>
            </div>
        </div>
    </section>

    <!-- 店舗情報 -->
    <section id="info" class="info section">
        <div class="container">
            <div class="section-header">
                <p class="section-subtitle">Information</p>
                <h2 class="section-title">店舗情報</h2>
            </div>
            <div class="info-content">
                <div class="info-table-wrapper">
                    <table class="info-table">
HTMLEOF

    cat >> "$output_file" <<EOF
                        <tr>
                            <th>店名</th>
                            <td>${shop_name}（${shop_name_reading}）</td>
                        </tr>
                        <tr>
                            <th>住所</th>
                            <td>${shop_address}</td>
                        </tr>
                        <tr>
                            <th>電話番号</th>
                            <td><a href="tel:${shop_tel}">${shop_tel}</a></td>
                        </tr>
                        <tr>
                            <th>営業時間</th>
                            <td>
                                <span class="info-time">
                                    <strong>ランチ</strong> ${lunch_hours}<br>
                                    <strong>ディナー</strong> ${dinner_hours}
                                </span>
                            </td>
                        </tr>
                        <tr>
                            <th>定休日</th>
                            <td>${closed_day}</td>
                        </tr>
                        <tr>
                            <th>席数</th>
                            <td>${seats}</td>
                        </tr>
EOF

    cat >> "$output_file" <<'HTMLEOF'
                        <tr>
                            <th>お支払い</th>
                            <td>現金 / クレジットカード / 電子マネー</td>
                        </tr>
                        <tr>
                            <th>ご予約</th>
                            <td>お電話にて承ります（当日予約可）</td>
                        </tr>
                    </table>
                </div>
                <div class="info-notes">
                    <h4>ご来店にあたって</h4>
                    <ul>
                        <li>コース料理は前日までにご予約ください</li>
                        <li>お子様連れのお客様はご相談ください</li>
                        <li>店内は全席禁煙です</li>
                        <li>アレルギー等ございましたらお申し付けください</li>
                    </ul>
                </div>
            </div>
        </div>
    </section>

    <!-- アクセス -->
    <section id="access" class="access section">
        <div class="container">
            <div class="section-header">
                <p class="section-subtitle">Access</p>
                <h2 class="section-title">アクセス</h2>
            </div>
            <div class="access-content">
                <div class="access-map">
                    <div class="map-placeholder">
                        <span>Google Map</span>
HTMLEOF

    cat >> "$output_file" <<EOF
                        <p>${shop_address}</p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
                    </div>
                </div>
                <div class="access-info">
                    <h4>電車でお越しの方</h4>
                    <ul>
                        <li>最寄り駅より徒歩5分</li>
                    </ul>
                    <h4>お車でお越しの方</h4>
                    <ul>
                        <li>専用駐車場はございません</li>
                        <li>近隣のコインパーキングをご利用ください</li>
                    </ul>
                </div>
            </div>
        </div>
    </section>

    <!-- フッター -->
    <footer class="footer">
        <div class="container">
            <div class="footer-content">
                <div class="footer-logo">
HTMLEOF

    cat >> "$output_file" <<EOF
                    <p class="footer-shop-name">${shop_name}</p>
                    <p class="footer-address">${shop_address}</p>
                    <p class="footer-tel">TEL: <a href="tel:${shop_tel}">${shop_tel}</a></p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
                </div>
                <div class="footer-hours">
                    <p class="footer-hours-title">営業時間</p>
HTMLEOF

    cat >> "$output_file" <<EOF
                    <p>ランチ ${lunch_hours}</p>
                    <p>ディナー ${dinner_hours}</p>
                    <p>定休日：${closed_day}</p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
                </div>
            </div>
            <div class="footer-bottom">
HTMLEOF

    local current_year
    current_year=$(date +%Y)
    cat >> "$output_file" <<EOF
                <p class="copyright">&copy; ${current_year} ${shop_name} All Rights Reserved.</p>
EOF

    cat >> "$output_file" <<'HTMLEOF'
            </div>
        </div>
    </footer>

    <!-- ページトップへ戻るボタン -->
    <a href="#top" class="back-to-top" aria-label="ページトップへ戻る">
        <span></span>
    </a>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const navToggle = document.querySelector('.nav-toggle');
            const navMenu = document.querySelector('.nav-menu');

            navToggle.addEventListener('click', function() {
                navToggle.classList.toggle('active');
                navMenu.classList.toggle('active');
            });

            document.querySelectorAll('.nav-menu a').forEach(link => {
                link.addEventListener('click', function() {
                    navToggle.classList.remove('active');
                    navMenu.classList.remove('active');
                });
            });

            const header = document.querySelector('.header');
            window.addEventListener('scroll', function() {
                header.classList.toggle('scrolled', window.scrollY > 100);
            });

            const backToTop = document.querySelector('.back-to-top');
            window.addEventListener('scroll', function() {
                backToTop.classList.toggle('visible', window.scrollY > 500);
            });

            document.querySelectorAll('a[href^="#"]').forEach(anchor => {
                anchor.addEventListener('click', function(e) {
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {
                        const headerHeight = document.querySelector('.header').offsetHeight;
                        window.scrollTo({
                            top: target.offsetTop - headerHeight,
                            behavior: 'smooth'
                        });
                    }
                });
            });
        });
    </script>
</body>
</html>
HTMLEOF
}

# ===== CSS生成関数 =====

generate_css() {
    local output_file="$1"

    cat > "$output_file" <<'CSSEOF'
/*
 * 飲食店紹介ページ - スタイルシート
 * 自動生成ファイル
 */

*, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    --color-primary: #5d4e37;
    --color-secondary: #8b7355;
    --color-accent: #c9a86c;
    --color-light: #f5f0e8;
    --color-dark: #2d2a26;
    --color-white: #fdfcfa;
    --color-text: #3d3a36;
    --color-text-light: #6b6560;
    --color-border: #d4ccc0;
    --font-serif: 'Noto Serif JP', serif;
    --font-sans: 'Noto Sans JP', sans-serif;
    --spacing-xs: 0.5rem;
    --spacing-sm: 1rem;
    --spacing-md: 2rem;
    --spacing-lg: 4rem;
    --spacing-xl: 6rem;
    --header-height: 80px;
    --transition: 0.3s ease;
    --shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
}

html { scroll-behavior: smooth; }

body {
    font-family: var(--font-sans);
    font-size: 16px;
    line-height: 1.8;
    color: var(--color-text);
    background-color: var(--color-white);
}

a {
    color: inherit;
    text-decoration: none;
    transition: var(--transition);
}

img { max-width: 100%; height: auto; vertical-align: middle; }
ul { list-style: none; }

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--spacing-md);
}

.section { padding: var(--spacing-xl) 0; }

.section-header {
    text-align: center;
    margin-bottom: var(--spacing-lg);
}

.section-subtitle {
    font-family: var(--font-serif);
    font-size: 0.875rem;
    color: var(--color-accent);
    letter-spacing: 0.2em;
    text-transform: uppercase;
    margin-bottom: var(--spacing-xs);
}

.section-title {
    font-family: var(--font-serif);
    font-size: 2rem;
    font-weight: 500;
    color: var(--color-primary);
    position: relative;
    display: inline-block;
}

.section-title::after {
    content: '';
    position: absolute;
    bottom: -10px;
    left: 50%;
    transform: translateX(-50%);
    width: 60px;
    height: 2px;
    background: var(--color-accent);
}

.header {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: var(--header-height);
    z-index: 1000;
    transition: var(--transition);
}

.header.scrolled {
    background: rgba(253, 252, 250, 0.95);
    box-shadow: var(--shadow);
}

.header-inner {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--spacing-md);
    height: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.logo a {
    font-family: var(--font-serif);
    font-size: 1.5rem;
    font-weight: 500;
    color: var(--color-white);
    text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.3);
}

.header.scrolled .logo a {
    color: var(--color-primary);
    text-shadow: none;
}

.nav-menu {
    display: flex;
    gap: var(--spacing-md);
}

.nav-menu a {
    font-size: 0.875rem;
    color: var(--color-white);
    text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.3);
    letter-spacing: 0.1em;
    position: relative;
}

.header.scrolled .nav-menu a {
    color: var(--color-text);
    text-shadow: none;
}

.nav-menu a::after {
    content: '';
    position: absolute;
    bottom: -5px;
    left: 0;
    width: 0;
    height: 1px;
    background: var(--color-accent);
    transition: var(--transition);
}

.nav-menu a:hover::after { width: 100%; }

.nav-toggle {
    display: none;
    flex-direction: column;
    justify-content: space-between;
    width: 30px;
    height: 20px;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
}

.nav-toggle span {
    display: block;
    width: 100%;
    height: 2px;
    background: var(--color-white);
    transition: var(--transition);
}

.header.scrolled .nav-toggle span { background: var(--color-primary); }

.hero {
    position: relative;
    height: 100vh;
    min-height: 600px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #5d4e37 0%, #3d352c 100%);
    overflow: hidden;
}

.hero-overlay {
    position: absolute;
    inset: 0;
    background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="1" fill="rgba(255,255,255,0.03)"/></svg>');
    background-size: 30px 30px;
}

.hero-content {
    position: relative;
    text-align: center;
    color: var(--color-white);
    padding: var(--spacing-md);
}

.hero-subtitle {
    font-family: var(--font-serif);
    font-size: 1rem;
    letter-spacing: 0.3em;
    margin-bottom: var(--spacing-sm);
    color: var(--color-accent);
}

.hero-title {
    font-family: var(--font-serif);
    font-size: 3.5rem;
    font-weight: 500;
    letter-spacing: 0.2em;
    margin-bottom: var(--spacing-md);
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
}

.hero-description {
    font-size: 1rem;
    line-height: 2.2;
    margin-bottom: var(--spacing-lg);
    opacity: 0.9;
}

.hero-button {
    display: inline-block;
    padding: 1rem 2.5rem;
    border: 1px solid var(--color-accent);
    color: var(--color-accent);
    font-size: 0.875rem;
    letter-spacing: 0.1em;
    transition: var(--transition);
}

.hero-button:hover {
    background: var(--color-accent);
    color: var(--color-dark);
}

.hero-scroll {
    position: absolute;
    bottom: 40px;
    left: 50%;
    transform: translateX(-50%);
    text-align: center;
    color: var(--color-white);
    opacity: 0.7;
}

.hero-scroll span {
    font-size: 0.75rem;
    letter-spacing: 0.2em;
    display: block;
    margin-bottom: 10px;
}

.scroll-line {
    width: 1px;
    height: 50px;
    background: var(--color-white);
    margin: 0 auto;
    animation: scrollLine 1.5s ease-in-out infinite;
}

@keyframes scrollLine {
    0% { transform: scaleY(0); transform-origin: top; }
    50% { transform: scaleY(1); transform-origin: top; }
    51% { transform-origin: bottom; }
    100% { transform: scaleY(0); transform-origin: bottom; }
}

.concept { background: var(--color-light); }

.concept-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--spacing-lg);
    align-items: center;
}

.concept-image-placeholder {
    aspect-ratio: 3/4;
    background: linear-gradient(135deg, var(--color-secondary) 0%, var(--color-primary) 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--color-white);
    font-family: var(--font-serif);
    border-radius: 4px;
}

.concept-text h3 {
    font-family: var(--font-serif);
    font-size: 1.5rem;
    font-weight: 500;
    color: var(--color-primary);
    margin-bottom: var(--spacing-md);
}

.concept-text p {
    margin-bottom: var(--spacing-sm);
    color: var(--color-text-light);
}

.concept-signature {
    font-family: var(--font-serif);
    margin-top: var(--spacing-md);
    text-align: right;
    color: var(--color-primary);
}

.menu-note {
    text-align: center;
    font-size: 0.875rem;
    color: var(--color-text-light);
    margin-bottom: var(--spacing-lg);
}

.menu-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--spacing-md);
}

.menu-category {
    background: var(--color-light);
    padding: var(--spacing-md);
    border-radius: 4px;
}

.menu-category-title {
    font-family: var(--font-serif);
    font-size: 1.25rem;
    font-weight: 500;
    color: var(--color-primary);
    text-align: center;
    padding-bottom: var(--spacing-sm);
    margin-bottom: var(--spacing-md);
    border-bottom: 1px solid var(--color-border);
}

.menu-item {
    padding: var(--spacing-sm) 0;
    border-bottom: 1px dotted var(--color-border);
}

.menu-item:last-child { border-bottom: none; }

.menu-item-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--spacing-sm);
}

.menu-item-name {
    font-weight: 500;
    color: var(--color-text);
}

.menu-item-price {
    font-family: var(--font-serif);
    color: var(--color-secondary);
    white-space: nowrap;
}

.menu-item-desc {
    font-size: 0.8rem;
    color: var(--color-text-light);
    margin-top: 4px;
}

.menu-tax-note {
    text-align: center;
    font-size: 0.8rem;
    color: var(--color-text-light);
    margin-top: var(--spacing-md);
}

.gallery { background: var(--color-primary); }
.gallery .section-subtitle { color: var(--color-accent); }
.gallery .section-title { color: var(--color-white); }
.gallery .section-title::after { background: var(--color-accent); }

.gallery-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--spacing-sm);
}

.gallery-item {
    overflow: hidden;
    border-radius: 4px;
}

.gallery-placeholder {
    aspect-ratio: 4/3;
    background: linear-gradient(135deg, var(--color-secondary) 0%, #6b5c47 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    color: var(--color-white);
    font-family: var(--font-serif);
    transition: var(--transition);
}

.gallery-item:hover .gallery-placeholder { transform: scale(1.05); }

.info { background: var(--color-light); }

.info-content {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: var(--spacing-lg);
}

.info-table {
    width: 100%;
    border-collapse: collapse;
}

.info-table th,
.info-table td {
    padding: var(--spacing-sm);
    border-bottom: 1px solid var(--color-border);
    text-align: left;
    vertical-align: top;
}

.info-table th {
    width: 120px;
    font-weight: 500;
    color: var(--color-primary);
    background: rgba(201, 168, 108, 0.1);
}

.info-table td a { color: var(--color-secondary); }
.info-table td a:hover { color: var(--color-accent); }

.info-notes {
    background: var(--color-white);
    padding: var(--spacing-md);
    border-radius: 4px;
    border-left: 3px solid var(--color-accent);
}

.info-notes h4 {
    font-family: var(--font-serif);
    font-size: 1rem;
    font-weight: 500;
    color: var(--color-primary);
    margin-bottom: var(--spacing-sm);
}

.info-notes ul {
    font-size: 0.875rem;
    color: var(--color-text-light);
}

.info-notes li {
    position: relative;
    padding-left: 1.2em;
    margin-bottom: 0.5em;
}

.info-notes li::before {
    content: '・';
    position: absolute;
    left: 0;
    color: var(--color-accent);
}

.access-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--spacing-lg);
}

.map-placeholder {
    aspect-ratio: 16/9;
    background: var(--color-light);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    color: var(--color-text-light);
    font-family: var(--font-serif);
}

.map-placeholder span {
    font-size: 1.5rem;
    margin-bottom: var(--spacing-xs);
}

.map-placeholder p { font-size: 0.875rem; }

.access-info h4 {
    font-family: var(--font-serif);
    font-size: 1rem;
    font-weight: 500;
    color: var(--color-primary);
    margin-bottom: var(--spacing-xs);
    margin-top: var(--spacing-md);
}

.access-info h4:first-child { margin-top: 0; }

.access-info ul {
    font-size: 0.9rem;
    color: var(--color-text-light);
}

.access-info li {
    position: relative;
    padding-left: 1.5em;
    margin-bottom: 0.5em;
}

.access-info li::before {
    content: '●';
    position: absolute;
    left: 0;
    font-size: 0.5em;
    color: var(--color-accent);
    top: 0.6em;
}

.footer {
    background: var(--color-dark);
    color: var(--color-white);
    padding: var(--spacing-lg) 0 var(--spacing-md);
}

.footer-content {
    display: flex;
    justify-content: space-between;
    padding-bottom: var(--spacing-md);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    margin-bottom: var(--spacing-md);
}

.footer-shop-name {
    font-family: var(--font-serif);
    font-size: 1.5rem;
    margin-bottom: var(--spacing-xs);
}

.footer-address,
.footer-tel {
    font-size: 0.875rem;
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 4px;
}

.footer-tel a:hover { color: var(--color-accent); }

.footer-hours-title {
    font-family: var(--font-serif);
    margin-bottom: var(--spacing-xs);
}

.footer-hours p {
    font-size: 0.875rem;
    color: rgba(255, 255, 255, 0.7);
    margin-bottom: 4px;
}

.footer-bottom { text-align: center; }

.copyright {
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.5);
}

.back-to-top {
    position: fixed;
    bottom: 30px;
    right: 30px;
    width: 50px;
    height: 50px;
    background: var(--color-primary);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0;
    visibility: hidden;
    transition: var(--transition);
    z-index: 100;
}

.back-to-top.visible {
    opacity: 1;
    visibility: visible;
}

.back-to-top:hover { background: var(--color-secondary); }

.back-to-top span {
    width: 10px;
    height: 10px;
    border-top: 2px solid var(--color-white);
    border-right: 2px solid var(--color-white);
    transform: rotate(-45deg);
    margin-top: 5px;
}

@media (max-width: 1024px) {
    .menu-grid { grid-template-columns: repeat(2, 1fr); }
    .menu-category:last-child { grid-column: span 2; }
}

@media (max-width: 768px) {
    :root { --header-height: 70px; }
    .section { padding: var(--spacing-lg) 0; }
    .section-title { font-size: 1.5rem; }

    .nav-toggle { display: flex; }

    .nav-menu {
        position: fixed;
        top: var(--header-height);
        left: 0;
        right: 0;
        background: var(--color-white);
        flex-direction: column;
        padding: var(--spacing-md);
        gap: 0;
        transform: translateY(-100%);
        opacity: 0;
        visibility: hidden;
        transition: var(--transition);
    }

    .nav-menu.active {
        transform: translateY(0);
        opacity: 1;
        visibility: visible;
    }

    .nav-menu a {
        display: block;
        padding: var(--spacing-sm);
        color: var(--color-text);
        text-shadow: none;
        border-bottom: 1px solid var(--color-border);
    }

    .nav-toggle.active span:nth-child(1) { transform: rotate(45deg) translate(5px, 5px); }
    .nav-toggle.active span:nth-child(2) { opacity: 0; }
    .nav-toggle.active span:nth-child(3) { transform: rotate(-45deg) translate(5px, -5px); }

    .hero-title { font-size: 2rem; letter-spacing: 0.1em; }
    .concept-content { grid-template-columns: 1fr; }
    .concept-image { order: -1; }
    .concept-image-placeholder { aspect-ratio: 16/9; }
    .menu-grid { grid-template-columns: 1fr; }
    .menu-category:last-child { grid-column: span 1; }
    .gallery-grid { grid-template-columns: repeat(2, 1fr); }
    .info-content { grid-template-columns: 1fr; }
    .info-table th { width: 100px; }
    .access-content { grid-template-columns: 1fr; }
    .footer-content { flex-direction: column; gap: var(--spacing-md); }
    .back-to-top { bottom: 20px; right: 20px; width: 45px; height: 45px; }
}

@media (max-width: 480px) {
    .container { padding: 0 var(--spacing-sm); }
    .hero-title { font-size: 1.75rem; }
    .hero-button { padding: 0.8rem 2rem; }
    .info-table th, .info-table td { display: block; width: 100%; }
    .info-table th { padding-bottom: 0.5rem; }
    .info-table td { padding-top: 0; padding-bottom: 1rem; }
    .gallery-grid { grid-template-columns: 1fr; }
}
CSSEOF
}

# ===== 引数解析 =====

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -o|--output)
                [[ $# -lt 2 ]] && show_error_and_exit "--output には値が必要です"
                output_dir="$2"
                shift 2
                ;;
            -n|--name)
                [[ $# -lt 2 ]] && show_error_and_exit "--name には値が必要です"
                shop_name="$2"
                shift 2
                ;;
            -r|--reading)
                [[ $# -lt 2 ]] && show_error_and_exit "--reading には値が必要です"
                shop_name_reading="$2"
                shift 2
                ;;
            -t|--tagline)
                [[ $# -lt 2 ]] && show_error_and_exit "--tagline には値が必要です"
                shop_tagline="$2"
                shift 2
                ;;
            -a|--address)
                [[ $# -lt 2 ]] && show_error_and_exit "--address には値が必要です"
                shop_address="$2"
                shift 2
                ;;
            -p|--phone)
                [[ $# -lt 2 ]] && show_error_and_exit "--phone には値が必要です"
                shop_tel="$2"
                shift 2
                ;;
            --owner)
                [[ $# -lt 2 ]] && show_error_and_exit "--owner には値が必要です"
                shop_owner="$2"
                shift 2
                ;;
            --lunch)
                [[ $# -lt 2 ]] && show_error_and_exit "--lunch には値が必要です"
                lunch_hours="$2"
                shift 2
                ;;
            --dinner)
                [[ $# -lt 2 ]] && show_error_and_exit "--dinner には値が必要です"
                dinner_hours="$2"
                shift 2
                ;;
            --closed)
                [[ $# -lt 2 ]] && show_error_and_exit "--closed には値が必要です"
                closed_day="$2"
                shift 2
                ;;
            --seats)
                [[ $# -lt 2 ]] && show_error_and_exit "--seats には値が必要です"
                seats="$2"
                shift 2
                ;;
            -*)
                show_error_and_exit "不明なオプション: $1"
                ;;
            *)
                show_error_and_exit "不明な引数: $1"
                ;;
        esac
    done
}

# ===== メイン処理 =====

#
# バナーを表示
#
show_banner() {
    echo -e "${C_CYAN}"
    echo "=================================="
    echo "  飲食店紹介ページ生成スクリプト"
    echo "  Version ${VERSION}"
    echo "=================================="
    echo -e "${C_RESET}"
}

#
# 結果を表示
#
show_result() {
    local html_file="$1"
    local css_file="$2"

    echo ""
    echo -e "${C_GREEN}========================================${C_RESET}"
    log_success "ページ生成が完了しました！"
    echo -e "${C_GREEN}========================================${C_RESET}"
    echo ""
    echo "生成されたファイル:"
    echo "  - ${html_file}"
    echo "  - ${css_file}"
    echo ""
    echo "店舗情報:"
    echo "  店名: ${shop_name}"
    echo "  住所: ${shop_address}"
    echo "  電話: ${shop_tel}"
    echo ""
    echo "ブラウザで ${html_file} を開いて確認してください。"
}

#
# メイン処理
#
main() {
    parse_arguments "$@"

    show_banner

    # 出力ディレクトリ作成
    log_info "出力ディレクトリを作成: ${output_dir}"
    mkdir -p "${output_dir}"

    # HTML生成
    local html_file="${output_dir}/index.html"
    log_info "HTMLファイルを生成: ${html_file}"
    generate_html "${html_file}"

    # CSS生成
    local css_file="${output_dir}/style.css"
    log_info "CSSファイルを生成: ${css_file}"
    generate_css "${css_file}"

    show_result "${html_file}" "${css_file}"

    exit 0
}

# スクリプト実行
main "$@"
