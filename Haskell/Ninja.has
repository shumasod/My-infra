<?php
/**
 * AWKコマンドユーティリティクラス
 * 
 * PHPアプリケーションからAWKコマンドを実行するためのラッパークラス
 * 
 * @author Claude
 * @version 1.1.0
 */
class AwkUtil
{
    /**
     * AWKコマンドを実行する
     *
     * @param string $script AWKスクリプト
     * @param string $filename 処理対象のファイル名
     * @param array $options 追加オプション
     * @return string 実行結果
     * @throws RuntimeException コマンド実行エラー時
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function execute(string $script, string $filename, array $options = []): string
    {
        // 入力値検証
        if (empty($script)) {
            throw new InvalidArgumentException('AWKスクリプトが空です');
        }
        
        if (!file_exists($filename)) {
            throw new InvalidArgumentException('ファイルが存在しません: ' . $filename);
        }
        
        if (!is_readable($filename)) {
            throw new InvalidArgumentException('ファイルが読み込めません: ' . $filename);
        }
        
        // 基本コマンドの構築
        $command = 'awk ';
        
        // オプションの処理
        if (isset($options['fieldSeparator'])) {
            $command .= '-F' . escapeshellarg($options['fieldSeparator']) . ' ';
        }
        
        // 変数の処理
        if (isset($options['variables']) && is_array($options['variables'])) {
            foreach ($options['variables'] as $name => $value) {
                if (!preg_match('/^[a-zA-Z_][a-zA-Z0-9_]*$/', $name)) {
                    throw new InvalidArgumentException('無効な変数名: ' . $name);
                }
                $command .= '-v ' . escapeshellarg($name) . '=' . escapeshellarg($value) . ' ';
            }
        }
        
        // スクリプトの追加
        $command .= escapeshellarg($script) . ' ';
        
        // ファイル名の追加
        $command .= escapeshellarg($filename);
        
        // コマンドの実行
        $output = [];
        $returnVar = 0;
        exec($command . ' 2>&1', $output, $returnVar);
        
        // エラーチェック
        if ($returnVar !== 0) {
            throw new RuntimeException('AWKコマンドの実行中にエラーが発生しました (終了コード: ' . $returnVar . '): ' . implode("\n", $output));
        }
        
        return implode("\n", $output);
    }
    
    /**
     * CSVファイルの特定列を抽出する
     *
     * @param string $filename CSVファイル名
     * @param array $columns 抽出する列番号の配列（1から始まる）
     * @param string $delimiter 区切り文字（デフォルトはカンマ）
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return string 実行結果
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function extractCsvColumns(string $filename, array $columns, string $delimiter = ',', bool $hasHeader = true): string
    {
        if (empty($columns)) {
            throw new InvalidArgumentException('列番号の配列が空です');
        }
        
        // 列番号の検証
        foreach ($columns as $col) {
            if (!is_int($col) || $col < 1) {
                throw new InvalidArgumentException('無効な列番号: ' . $col);
            }
        }
        
        // 列番号の文字列を構築
        $columnsStr = implode(', ', array_map(function($col) {
            return '$' . $col;
        }, $columns));
        
        // AWKスクリプトの構築
        $script = 'BEGIN { OFS="' . str_replace('"', '\\"', $delimiter) . '" } ';
        
        // ヘッダー行の処理
        if ($hasHeader) {
            $script .= 'NR == 1 { print ' . $columnsStr . ' } ';
        }
        
        // データ行の処理
        $script .= ($hasHeader ? 'NR > 1' : '') . ' { print ' . $columnsStr . ' }';
        
        // コマンドの実行
        return self::execute($script, $filename, [
            'fieldSeparator' => $delimiter
        ]);
    }
    
    /**
     * ログファイルから特定のパターンに一致する行を抽出する
     *
     * @param string $filename ログファイル名
     * @param string $pattern 検索パターン
     * @return string 実行結果
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function grepFromLog(string $filename, string $pattern): string
    {
        if (empty($pattern)) {
            throw new InvalidArgumentException('検索パターンが空です');
        }
        
        // AWKスクリプトの構築（パターンのエスケープ処理）
        $escapedPattern = str_replace(['/', '\\'], ['\\/', '\\\\'], $pattern);
        $script = '/' . $escapedPattern . '/ { print $0 }';
        
        // コマンドの実行
        return self::execute($script, $filename);
    }
    
    /**
     * ログファイルから条件に一致する行を集計する
     *
     * @param string $filename ログファイル名
     * @param int $columnIndex 集計対象の列インデックス（1から始まる）
     * @param string $condition 集計条件（AWK形式）
     * @return string 実行結果
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function aggregateLog(string $filename, int $columnIndex, string $condition = ''): string
    {
        if ($columnIndex < 1) {
            throw new InvalidArgumentException('無効な列インデックス: ' . $columnIndex);
        }
        
        // 条件の追加
        $conditionStr = $condition ? $condition . ' ' : '';
        
        // AWKスクリプトの構築
        $script = 'BEGIN { print "値,出現回数" } ' .
                  $conditionStr . '{ count[$' . $columnIndex . ']++ } ' .
                  'END { for (val in count) print val "," count[val] }';
        
        // コマンドの実行
        return self::execute($script, $filename);
    }
    
    /**
     * CSVファイルの列の合計値を計算する
     *
     * @param string $filename CSVファイル名
     * @param int $columnIndex 計算対象の列インデックス（1から始まる）
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return float 合計値
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function sumCsvColumn(string $filename, int $columnIndex, bool $hasHeader = true): float
    {
        if ($columnIndex < 1) {
            throw new InvalidArgumentException('無効な列インデックス: ' . $columnIndex);
        }
        
        // AWKスクリプトの構築
        $script = 'BEGIN { sum = 0 } ' .
                  ($hasHeader ? 'NR > 1 ' : '') . '{ if ($' . $columnIndex . ' ~ /^[0-9]*\.?[0-9]+$/) sum += $' . $columnIndex . ' } ' .
                  'END { print sum }';
        
        // コマンドの実行
        $result = self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
        
        return (float)trim($result);
    }
    
    /**
     * テキストファイルの行数を数える
     *
     * @param string $filename ファイル名
     * @return int 行数
     */
    public static function countLines(string $filename): int
    {
        // AWKスクリプトの構築
        $script = 'END { print NR }';
        
        // コマンドの実行
        $result = self::execute($script, $filename);
        
        return (int)trim($result);
    }
    
    /**
     * CSVファイルをHTML表に変換する
     *
     * @param string $filename CSVファイル名
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @param string $tableClass テーブルに適用するCSSクラス
     * @return string HTML表
     */
    public static function csvToHtmlTable(string $filename, bool $hasHeader = true, string $tableClass = 'table table-bordered'): string
    {
        // AWKスクリプトの構築
        $script = 'BEGIN { 
            FS = ","
            print "<table class=\"' . htmlspecialchars($tableClass, ENT_QUOTES) . '\">"
        } ';
        
        if ($hasHeader) {
            // ヘッダー行の処理
            $script .= 'NR == 1 { 
                print "  <thead>"
                print "    <tr>"
                for (i = 1; i <= NF; i++) {
                    gsub(/"/, "", $i)
                    print "      <th>" $i "</th>"
                }
                print "    </tr>"
                print "  </thead>"
                print "  <tbody>"
            } ';
            
            // データ行の処理
            $script .= 'NR > 1 { 
                print "    <tr>"
                for (i = 1; i <= NF; i++) {
                    gsub(/"/, "", $i)
                    gsub(/&/, "\\&amp;", $i)
                    gsub(/</, "\\&lt;", $i)
                    gsub(/>/, "\\&gt;", $i)
                    print "      <td>" $i "</td>"
                }
                print "    </tr>"
            } ';
        } else {
            // ヘッダーなしの場合
            $script .= '{ 
                if (NR == 1) print "  <tbody>"
                print "    <tr>"
                for (i = 1; i <= NF; i++) {
                    gsub(/"/, "", $i)
                    gsub(/&/, "\\&amp;", $i)
                    gsub(/</, "\\&lt;", $i)
                    gsub(/>/, "\\&gt;", $i)
                    print "      <td>" $i "</td>"
                }
                print "    </tr>"
            } ';
        }
        
        $script .= 'END { 
            print "  </tbody>"
            print "</table>"
        }';
        
        // コマンドの実行
        return self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
    }
    
    /**
     * CSVファイルの平均値を計算する
     *
     * @param string $filename CSVファイル名
     * @param int $columnIndex 計算対象の列インデックス（1から始まる）
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return float 平均値
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function averageCsvColumn(string $filename, int $columnIndex, bool $hasHeader = true): float
    {
        if ($columnIndex < 1) {
            throw new InvalidArgumentException('無効な列インデックス: ' . $columnIndex);
        }
        
        // AWKスクリプトの構築
        $script = 'BEGIN { sum = 0; count = 0 } ' .
                  ($hasHeader ? 'NR > 1 ' : '') . '{ 
                      if ($' . $columnIndex . ' ~ /^[0-9]*\.?[0-9]+$/) { 
                          sum += $' . $columnIndex . '; 
                          count++ 
                      } 
                  } ' .
                  'END { if (count > 0) print sum / count; else print 0 }';
        
        // コマンドの実行
        $result = self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
        
        return (float)trim($result);
    }
    
    /**
     * CSVファイルの最大値を取得する
     *
     * @param string $filename CSVファイル名
     * @param int $columnIndex 計算対象の列インデックス（1から始まる）
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return float 最大値
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function maxCsvColumn(string $filename, int $columnIndex, bool $hasHeader = true): float
    {
        if ($columnIndex < 1) {
            throw new InvalidArgumentException('無効な列インデックス: ' . $columnIndex);
        }
        
        // AWKスクリプトの構築
        $script = 'BEGIN { max = ""; first = 1 } ' .
                  ($hasHeader ? 'NR > 1 ' : '') . '{ 
                      if ($' . $columnIndex . ' ~ /^[0-9]*\.?[0-9]+$/) { 
                          if (first || $' . $columnIndex . ' > max) { 
                              max = $' . $columnIndex . '; 
                              first = 0 
                          } 
                      } 
                  } ' .
                  'END { print max }';
        
        // コマンドの実行
        $result = self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
        
        return (float)trim($result);
    }
    
    /**
     * CSVファイルの最小値を取得する
     *
     * @param string $filename CSVファイル名
     * @param int $columnIndex 計算対象の列インデックス（1から始まる）
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return float 最小値
     * @throws InvalidArgumentException 引数エラー時
     */
    public static function minCsvColumn(string $filename, int $columnIndex, bool $hasHeader = true): float
    {
        if ($columnIndex < 1) {
            throw new InvalidArgumentException('無効な列インデックス: ' . $columnIndex);
        }
        
        // AWKスクリプトの構築
        $script = 'BEGIN { min = ""; first = 1 } ' .
                  ($hasHeader ? 'NR > 1 ' : '') . '{ 
                      if ($' . $columnIndex . ' ~ /^[0-9]*\.?[0-9]+$/) { 
                          if (first || $' . $columnIndex . ' < min) { 
                              min = $' . $columnIndex . '; 
                              first = 0 
                          } 
                      } 
                  } ' .
                  'END { print min }';
        
        // コマンドの実行
        $result = self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
        
        return (float)trim($result);
    }
}