<?php
/**
 * AWKコマンドユーティリティクラス
 * 
 * PHPアプリケーションからAWKコマンドを実行するためのラッパークラス
 * 
 * @author Claude
 * @version 1.0.0
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
     */
    public static function execute(string $script, string $filename, array $options = []): string
    {
        // 基本コマンドの構築
        $command = 'awk ';
        
        // オプションの処理
        if (isset($options['fieldSeparator'])) {
            $command .= '-F' . escapeshellarg($options['fieldSeparator']) . ' ';
        }
        
        // 変数の処理
        if (isset($options['variables']) && is_array($options['variables'])) {
            foreach ($options['variables'] as $name => $value) {
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
        exec($command, $output, $returnVar);
        
        // エラーチェック
        if ($returnVar !== 0) {
            throw new RuntimeException('AWKコマンドの実行中にエラーが発生しました: ' . implode("\n", $output));
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
     */
    public static function extractCsvColumns(string $filename, array $columns, string $delimiter = ',', bool $hasHeader = true): string
    {
        // 列番号の文字列を構築
        $columnsStr = implode(', ', array_map(function($col) {
            return '$' . $col;
        }, $columns));
        
        // AWKスクリプトの構築
        $script = 'BEGIN { OFS="' . $delimiter . '" } ';
        
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
     */
    public static function grepFromLog(string $filename, string $pattern): string
    {
        // AWKスクリプトの構築
        $script = '/' . str_replace('/', '\\/', $pattern) . '/ { print $0 }';
        
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
     */
    public static function aggregateLog(string $filename, int $columnIndex, string $condition = ''): string
    {
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
     */
    public static function sumCsvColumn(string $filename, int $columnIndex, bool $hasHeader = true): float
    {
        // AWKスクリプトの構築
        $script = 'BEGIN { sum = 0 } ' .
                  ($hasHeader ? 'NR > 1 ' : '') . '{ sum += $' . $columnIndex . ' } ' .
                  'END { print sum }';
        
        // コマンドの実行
        $result = self::execute($script, $filename, [
            'fieldSeparator' => ','
        ]);
        
        return (float)$result;
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
        
        return (int)$result;
    }
    
    /**
     * CSVファイルをHTML表に変換する
     *
     * @param string $filename CSVファイル名
     * @param bool $hasHeader ヘッダー行を含むかどうか
     * @return string HTML表
     */
    public static function csvToHtmlTable(string $filename, bool $hasHeader = true): string
    {
        // AWKスクリプトの構築
        $script = 'BEGIN { print "<table class=\"table table-bordered\">" } ' .
