import Control.Concurrent (threadDelay)
import System.Process (callCommand)
import Network.Socket (withSocketsDo)
import Network.HTTP.Simple (httpGetResponseBody, getResponseBody, getResponseStatusCode, httpLBS, parseRequest)

-- ネットワーク接続を確認するURL
url :: String
url = "http://www.google.com"

-- ネットワーク接続を確認し、正常ならTrueを返す
checkNetworkConnection :: IO Bool
checkNetworkConnection = withSocketsDo $ do
    request <- parseRequest url
    response <- httpLBS request
    return $ getResponseStatusCode response == 200

-- ネットワーク再接続を行う
reconnectNetwork :: IO ()
reconnectNetwork = do
    -- ここにネットワーク再接続のためのコマンドを記述する
    -- 例: callCommand "sudo service networking restart"
    return ()

-- メイン関数
main :: IO ()
main = do
    -- 監視間隔（秒）
    let monitoringInterval = 300 -- 5分ごとに監視

    -- メインループ
    mainLoop monitoringInterval

-- メインループ関数
mainLoop :: Int -> IO ()
mainLoop interval = do
    -- ネットワーク接続を確認
    isConnected <- checkNetworkConnection
    if not isConnected
        then do
            putStrLn "ネットワーク接続が切れています。再接続を試みます。"
            reconnectNetwork
        else putStrLn "ネットワーク接続が正常です。"

    -- 次の監視まで待機
    threadDelay (interval * 1000000)
    mainLoop interval
