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

-- アプリケーションの設定
data Config = Config
  { checkUrls :: [String]  -- 複数URLをチェック可能に
  , interval :: Int        -- 監視間隔（秒）
  , maxRetries :: Int      -- 再接続の最大試行回数
  , verbose :: Bool        -- 詳細ログ出力
  }

-- デフォルト設定
defaultConfig :: Config
defaultConfig = Config
  { checkUrls = ["https://www.google.com", "https://www.yahoo.co.jp"]
  , interval = 300  -- 5分
  , maxRetries = 3
  , verbose = False
  }

-- ログレベル
data LogLevel = Info | Warning | Error | Debug
  deriving (Show, Eq)

-- タイムスタンプ付きでログを出力
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

-- ネットワーク接続を確認する（エラーハンドリング付き）
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
    handleHttpException :: HttpException -> IO Bool
    handleHttpException e = do
      logMessage Error $ printf "%s への接続エラー: %s" url (show e)
      return False

-- OSに適したネットワーク再接続コマンドを取得
getReconnectCommand :: IO String
getReconnectCommand = case os of
  "linux"   -> return "sudo systemctl restart NetworkManager"
  "darwin"  -> return "sudo ifconfig en0 down && sudo ifconfig en0 up"  -- macOS用
  "mingw32" -> return "ipconfig /release && ipconfig /renew"  -- Windows用
  _         -> do
    logMessage Warning $ "未対応OS: " ++ os ++ "、一般的なコマンドを使用します"
    return "ping -c 1 127.0.0.1"  -- 代替コマンド

-- ネットワーク再接続を実行（エラーハンドリング付き）
reconnectNetwork :: IO Bool
reconnectNetwork = do
  cmd <- getReconnectCommand
  logMessage Info $ "ネットワーク再接続を試みます: " ++ cmd
  
  result <- try $ do
    (exitCode, stdout, stderr) <- readProcessWithExitCode "sh" ["-c", cmd] ""
    logMessage Debug $ "実行結果: " ++ stdout
    when (not $ null stderr) $ logMessage Warning $ "エラー出力: " ++ stderr
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

-- すべてのURLをチェックし、一つでも接続できればTrueを返す
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

-- ネットワーク監視のメインループ
monitorNetwork :: Config -> Int -> IO ()
monitorNetwork config retryCount = do
  isConnected <- checkAllConnections config
  
  if isConnected
    then do
      logMessage Info "ネットワーク接続が正常です"
      threadDelay (interval config * 1000000)
      monitorNetwork config 0  -- 再試行カウントをリセット
    else do
      if retryCount >= maxRetries config
        then do
          logMessage Error $ printf "最大再試行回数(%d)に達しました" (maxRetries config)
          threadDelay (interval config * 1000000)
          monitorNetwork config 0  -- 再試行カウントをリセット
        else do
          logMessage Warning $ printf "ネットワーク接続が切れています (試行 %d/%d)" 
                                     (retryCount + 1) (maxRetries config)
          reconnectSuccess <- reconnectNetwork
          
          -- 再接続後の確認待機
          logMessage Info "再接続後の確認のため10秒待機します..."
          threadDelay (10 * 1000000)
          
          -- 再接続結果の確認
          reconnectedOk <- checkAllConnections config
          if reconnectedOk
            then do
              logMessage Info "再接続に成功しました"
              threadDelay (interval config * 1000000)
              monitorNetwork config 0  -- 再試行カウントをリセット
            else do
              logMessage Warning "再接続が成功していません。再試行します"
              threadDelay (30 * 1000000)  -- 再試行前に30秒待機
              monitorNetwork config (retryCount + 1)

-- ヘルプを表示
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

-- コマンドライン引数を解析して設定を更新
parseArgs :: [String] -> Config -> IO Config
parseArgs [] config = return config
parseArgs ("--help":_) _ = showHelp >> exitSuccess
parseArgs ("-h":_) _ = showHelp >> exitSuccess
parseArgs ("--verbose":args) config = parseArgs args (config { verbose = True })
parseArgs ("-v":args) config = parseArgs args (config { verbose = True })
parseArgs (arg:args) config
  | "--interval=" `isPrefixOf` arg = 
      let val = drop 11 arg in
      if all isDigit val && not (null val)
        then parseArgs args (config { interval = read val })
        else do
          logMessage Error $ "無効な間隔値: " ++ val
          exitFailure
  | "--retries=" `isPrefixOf` arg = 
      let val = drop 10 arg in
      if all isDigit val && not (null val)
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

-- 追加のインポート
import Data.List (isPrefixOf)
import Data.Char (isDigit)

-- メイン関数
main :: IO ()
main = withSocketsDo $ do
  args <- getArgs
  config <- parseArgs args defaultConfig
  
  -- 設定情報を表示
  logMessage Info $ printf "ネットワーク監視を開始します (間隔: %d秒, 最大再試行回数: %d)" 
                         (interval config) (maxRetries config)
  logMessage Info $ "監視URL: " ++ show (checkUrls config)
  
  -- 初期接続チェック
  initialCheck <- checkAllConnections config
  if not initialCheck
    then logMessage Warning "初期接続チェックに失敗しました。ネットワークに問題がある可能性があります。"
    else logMessage Info "初期接続チェックに成功しました。"
  
  -- メインループ
  monitorNetwork config 0
