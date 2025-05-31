{-|
Module      : Main
Description : ネットワーク接続監視ツール
Copyright   : (c) 2025
License     : MIT
Maintainer  : admin@example.com

このツールは、指定されたURLへの接続を定期的に監視し、
接続が失われた場合に自動的に再接続を試みます。
複数のURLを監視できるほか、監視間隔や再試行回数などの
設定をコマンドライン引数で指定できます。
-}
module Main where

import Control.Concurrent (threadDelay, forkIO)
import Control.Exception (try, SomeException, handle, catch)
import Control.Monad (forever, void, when)
import Data.Time (getCurrentTime, formatTime, defaultTimeLocale)
import System.Environment (getArgs, getProgName)
import System.Exit (exitSuccess, exitFailure)
import System.Process (callCommand, readProcessWithExitCode)
import System.Info (os)
import Network.Socket (withSocketsDo)
import Network.HTTP.Simple (httpLBS, parseRequest, getResponseStatusCode, HttpException(..))
import qualified Data.ByteString.Lazy.Char8 as BL
import Text.Printf (printf)
import System.IO (hFlush, stdout)
import Data.List (isPrefixOf)
import Data.Char (isDigit)

-- -----------------------------------------------------------------------------
-- 型定義
-- -----------------------------------------------------------------------------

-- | アプリケーションの設定を表すデータ型
data Config = Config
  { checkUrls  :: [String]  -- ^ 監視対象のURL一覧
  , interval   :: Int       -- ^ 監視間隔（秒）
  , maxRetries :: Int       -- ^ 再接続の最大試行回数
  , verbose    :: Bool      -- ^ 詳細ログ出力フラグ
  } deriving (Show)

-- | ログレベルを表す型
data LogLevel = Info | Warning | Error | Debug
  deriving (Show, Eq)

-- -----------------------------------------------------------------------------
-- 定数定義
-- -----------------------------------------------------------------------------

-- | デフォルト設定
defaultConfig :: Config
defaultConfig = Config
  { checkUrls  = ["https://www.google.com", "https://www.yahoo.co.jp"]
  , interval   = 300  -- 5分
  , maxRetries = 3
  , verbose    = False
  }

-- | 再接続後の待機時間（秒）
reconnectWaitTime :: Int
reconnectWaitTime = 10

-- | 再試行前の待機時間（秒）
retryWaitTime :: Int
retryWaitTime = 30

-- -----------------------------------------------------------------------------
-- ログ関連関数
-- -----------------------------------------------------------------------------

-- | タイムスタンプ付きでログを出力する
--
-- 指定されたログレベルとメッセージに現在時刻を付加して出力します。
-- ログレベルに応じたプレフィックス([INFO], [WARNING]など)が自動的に付与されます。
--
-- >>> logMessage Info "アプリケーションを開始します"
-- 2025-05-18 12:34:56 [INFO] アプリケーションを開始します
logMessage :: LogLevel -> String -> IO ()
logMessage level msg = do
  timestamp <- getCurrentTime >>= return . formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S"
  let prefix = case level of
        Info    -> "[INFO]"
        Warning -> "[WARNING]"
        Error   -> "[ERROR]"
        Debug   -> "[DEBUG]"
  printf "%s %s %s\n" timestamp prefix msg
  hFlush stdout

-- -----------------------------------------------------------------------------
-- ネットワーク関連関数
-- -----------------------------------------------------------------------------

-- | 指定されたURLに接続できるかを確認する
--
-- URLに対してHTTPリクエストを行い、
-- 接続成功（ステータスコード200-299）の場合はTrueを、
-- それ以外の場合はFalseを返します。
-- ネットワークエラーは適切にハンドリングされます。
--
-- >>> checkNetworkConnection "https://www.google.com"
-- 接続確認中: https://www.google.com
-- https://www.google.com への接続結果: 200
-- True
checkNetworkConnection :: String -> IO Bool
checkNetworkConnection url = handle handleHttpException $ do
  logMessage Debug $ "接続確認中: " ++ url
  request <- parseRequest url
  response <- httpLBS request
  let statusCode = getResponseStatusCode response
  let isSuccess = statusCode >= 200 && statusCode < 300
  logMessage Debug $ printf "%s への接続結果: %d" url statusCode
  return isSuccess
  where
    -- HTTP例外を処理するハンドラ
    handleHttpException :: HttpException -> IO Bool
    handleHttpException e = do
      logMessage Error $ printf "%s への接続エラー: %s" url (show e)
      return False

-- | 現在のOSに適したネットワーク再接続コマンドを取得する
--
-- 実行環境のOSを自動判別し、適切なネットワーク再接続コマンドを返します。
-- Linux、macOS、Windowsに対応し、未対応OSの場合は代替コマンドを返します。
getReconnectCommand :: IO String
getReconnectCommand = case os of
  "linux"   -> return "sudo systemctl restart NetworkManager"
  "darwin"  -> return "sudo ifconfig en0 down && sudo ifconfig en0 up"  -- macOS用
  "mingw32" -> return "ipconfig /release && ipconfig /renew"  -- Windows用
  _         -> do
    logMessage Warning $ "未対応OS: " ++ os ++ "、一般的なコマンドを使用します"
    return "ping -c 1 127.0.0.1"  -- 代替コマンド

-- | ネットワーク再接続を試みる
--
-- OS固有の再接続コマンドを実行し、その結果を返します。
-- コマンド実行時の例外は適切にハンドリングされます。
reconnectNetwork :: IO Bool
reconnectNetwork = do
  cmd <- getReconnectCommand
  logMessage Info $ "ネットワーク再接続を試みます: " ++ cmd
  
  result <- try $ do
    (exitCode, stdout, stderr) <- readProcessWithExitCode "sh" ["-c", cmd] ""
    logMessage Debug $ "実行結果: " ++ stdout
    when (not $ null stderr) $ 
      logMessage Warning $ "エラー出力: " ++ stderr
    return $ null stderr
  
  case result of
    Left e -> do
      logMessage Error $ "再接続コマンド実行エラー: " ++ show (e :: SomeException)
      return False
    Right success -> do
      logMessage Info $ if success 
                        then "再接続コマンドは正常に実行されました" 
                        else "再接続コマンドの実行に問題がありました"
      return success

-- | 設定で指定されたすべてのURLの接続状態をチェックする
--
-- すべてのURLに対して接続チェックを行い、
-- 一つでも接続できればTrueを返します。
-- 詳細ログモード時は各URLの接続結果も出力します。
checkAllConnections :: Config -> IO Bool
checkAllConnections config = do
  results <- mapM checkNetworkConnection (checkUrls config)
  let anyConnected = or results
  
  when (verbose config) $ do
    let urlResults = zip (checkUrls config) results
    mapM_ (\(url, result) -> 
            logMessage Debug $ printf "%s: %s" url (if result then "接続OK" else "接続NG")) 
          urlResults
  
  return anyConnected

-- -----------------------------------------------------------------------------
-- メイン監視ロジック
-- -----------------------------------------------------------------------------

-- | ネットワーク監視のメインループ処理
--
-- 指定された設定に基づき、ネットワーク接続を定期的に監視します。
-- 接続切れを検出した場合は再接続を試み、最大再試行回数に達するまで繰り返します。
monitorNetwork :: Config -> Int -> IO ()
monitorNetwork config retryCount = do
  isConnected <- checkAllConnections config
  
  if isConnected
    then do
      -- 接続正常時の処理
      logMessage Info "ネットワーク接続が正常です"
      threadDelay (interval config * 1000000)
      monitorNetwork config 0  -- 再試行カウントをリセット
    else do
      -- 接続切れ時の処理
      if retryCount >= maxRetries config
        then do
          -- 最大再試行回数に達した場合
          logMessage Error $ printf "最大再試行回数(%d)に達しました" (maxRetries config)
          threadDelay (interval config * 1000000)
          monitorNetwork config 0  -- 再試行カウントをリセット
        else do
          -- 再試行処理
          logMessage Warning $ printf "ネットワーク接続が切れています (試行 %d/%d)" 
                                     (retryCount + 1) (maxRetries config)
          reconnectSuccess <- reconnectNetwork
          
          -- 再接続後の確認待機
          logMessage Info $ printf "再接続後の確認のため%d秒待機します..." reconnectWaitTime
          threadDelay (reconnectWaitTime * 1000000)
          
          -- 再接続結果の確認
          reconnectedOk <- checkAllConnections config
          if reconnectedOk
            then do
              -- 再接続成功時
              logMessage Info "再接続に成功しました"
              threadDelay (interval config * 1000000)
              monitorNetwork config 0  -- 再試行カウントをリセット
            else do
              -- 再接続失敗時
              logMessage Warning "再接続が成功していません。再試行します"
              logMessage Info $ printf "再試行前に%d秒待機します..." retryWaitTime
              threadDelay (retryWaitTime * 1000000)
              monitorNetwork config (retryCount + 1)

-- -----------------------------------------------------------------------------
-- コマンドライン引数処理
-- -----------------------------------------------------------------------------

-- | ヘルプメッセージを表示する
showHelp :: IO ()
showHelp = do
  progName <- getProgName
  putStrLn $ "使用法: " ++ progName ++ " [オプション]"
  putStrLn "オプション:"
  putStrLn "  --help, -h       このヘルプを表示"
  putStrLn "  --interval=N     監視間隔を N 秒に設定 (デフォルト: 300)"
  putStrLn "  --retries=N      最大再試行回数を N に設定 (デフォルト: 3)"
  putStrLn "  --verbose, -v    詳細ログを出力"
  putStrLn "  --url=URL        チェックするURLを追加 (複数指定可)"
  putStrLn ""
  putStrLn "例:"
  putStrLn $ "  " ++ progName ++ " --interval=60 --retries=5 --url=https://example.com"

-- | 数値文字列の検証
--
-- 文字列が正の整数を表しているかを確認します。
-- 空文字列または非数値文字を含む場合はFalseを返します。
isValidNumber :: String -> Bool
isValidNumber s = not (null s) && all isDigit s

-- | コマンドライン引数を解析して設定を更新する
--
-- 指定されたコマンドライン引数に基づき、設定を更新します。
-- 無効な引数があればエラーメッセージを表示して終了します。
parseArgs :: [String] -> Config -> IO Config
parseArgs [] config = return config
parseArgs ("--help":_) _ = showHelp >> exitSuccess
parseArgs ("-h":_) _ = showHelp >> exitSuccess
parseArgs ("--verbose":args) config = parseArgs args (config { verbose = True })
parseArgs ("-v":args) config = parseArgs args (config { verbose = True })
parseArgs (arg:args) config
  | "--interval=" `isPrefixOf` arg = 
      let val = drop 11 arg in
      if isValidNumber val
        then parseArgs args (config { interval = read val })
        else do
          logMessage Error $ "無効な間隔値: " ++ val
          exitFailure
  | "--retries=" `isPrefixOf` arg = 
      let val = drop 10 arg in
      if isValidNumber val
        then parseArgs args (config { maxRetries = read val })
        else do
          logMessage Error $ "無効な再試行回数: " ++ val
          exitFailure
  | "--url=" `isPrefixOf` arg =
      let url = drop 6 arg in
      parseArgs args (config { checkUrls = url : checkUrls config })
  | otherwise = do
      logMessage Error $ "不明な引数: " ++ arg
      showHelp
      exitFailure

-- -----------------------------------------------------------------------------
-- メイン関数
-- -----------------------------------------------------------------------------

-- | アプリケーションのエントリーポイント
--
-- 1. コマンドライン引数を解析して設定を読み込む
-- 2. 設定情報を表示
-- 3. 初期接続チェックを実行
-- 4. ネットワーク監視ループを開始
main :: IO ()
main = withSocketsDo $ do
  -- バナー表示
  putStrLn "==============================================="
  putStrLn "=          ネットワーク監視ツール            ="
  putStrLn "==============================================="

  -- 引数解析
  args <- getArgs
  config <- parseArgs args defaultConfig
  
  -- 設定情報を表示
  logMessage Info $ printf "ネットワーク監視を開始します (間隔: %d秒, 最大再試行回数: %d)" 
                         (interval config) (maxRetries config)
  logMessage Info $ "監視URL: " ++ show (checkUrls config)
  
  -- 初期接続チェック
  logMessage Info "初期接続チェックを実行しています..."
  initialCheck <- checkAllConnections config
  if not initialCheck
    then logMessage Warning "初期接続チェックに失敗しました。ネットワークに問題がある可能性があります。"
    else logMessage Info "初期接続チェックに成功しました。"
  
  -- メインループ
  logMessage Info "監視ループを開始します..."
  monitorNetwork config 0
