import React, { useState, useEffect } from ‘react’;

const DiceBattleGame = () => {
const [gameState, setGameState] = useState(‘start’); // ‘start’, ‘playerRoll’, ‘computerRoll’, ‘result’, ‘stats’
const [playerDice, setPlayerDice] = useState(null);
const [computerDice, setComputerDice] = useState(null);
const [totalPlays, setTotalPlays] = useState(0);
const [wins, setWins] = useState(0);
const [draws, setDraws] = useState(0);
const [gameResult, setGameResult] = useState(’’);
const [isRolling, setIsRolling] = useState(false);
const [rollingValue, setRollingValue] = useState(1);

// サイコロの目を表示するコンポーネント
const DiceDisplay = ({ number, color = ‘text-white’, bgColor = ‘border-white’, isAnimating = false }) => {
const getDicePattern = (num) => {
const patterns = {
1: [
[’’, ‘’, ‘’],
[’’, ‘●’, ‘’],
[’’, ‘’, ‘’]
],
2: [
[‘●’, ‘’, ‘’],
[’’, ‘’, ‘’],
[’’, ‘’, ‘●’]
],
3: [
[‘●’, ‘’, ‘’],
[’’, ‘●’, ‘’],
[’’, ‘’, ‘●’]
],
4: [
[‘●’, ‘’, ‘●’],
[’’, ‘’, ‘’],
[‘●’, ‘’, ‘●’]
],
5: [
[‘●’, ‘’, ‘●’],
[’’, ‘●’, ‘’],
[‘●’, ‘’, ‘●’]
],
6: [
[‘●’, ‘’, ‘●’],
[‘●’, ‘’, ‘●’],
[‘●’, ‘’, ‘●’]
]
};
return patterns[num] || patterns[1];
};

```
const pattern = getDicePattern(number);

return (
  <div className="relative">
    <div className={`inline-block border-4 ${bgColor} p-4 rounded-lg bg-gray-900 transition-all duration-150 ${
      isAnimating 
        ? 'animate-spin transform scale-125 shadow-2xl shadow-white/20 border-8' 
        : 'hover:scale-105'
    }`}
    style={{
      transform: isAnimating 
        ? `rotateX(${Math.random() * 360}deg) rotateY(${Math.random() * 360}deg) rotateZ(${Math.random() * 360}deg) scale(1.3)` 
        : 'none',
      animation: isAnimating ? 'diceRoll 0.15s infinite linear' : 'none'
    }}>
      <div className={`font-mono text-2xl leading-tight transition-all duration-150 ${
        isAnimating ? 'blur-sm' : ''
      }`}>
        {pattern.map((row, rowIndex) => (
          <div key={rowIndex} className="flex justify-center space-x-2">
            {row.map((cell, cellIndex) => (
              <div key={cellIndex} className={`w-6 h-6 flex items-center justify-center ${color} ${
                isAnimating ? 'animate-pulse' : ''
              }`}>
                {cell}
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
    
    {/* 転がりエフェクト */}
    {isAnimating && (
      <>
        <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-transparent via-white/10 to-transparent animate-ping"></div>
        <div className="absolute -top-2 -left-2 w-4 h-4 bg-yellow-400 rounded-full animate-bounce opacity-70"></div>
        <div className="absolute -bottom-2 -right-2 w-3 h-3 bg-red-400 rounded-full animate-bounce opacity-70" style={{animationDelay: '0.2s'}}></div>
        <div className="absolute -top-2 -right-2 w-2 h-2 bg-blue-400 rounded-full animate-bounce opacity-70" style={{animationDelay: '0.4s'}}></div>
      </>
    )}
    
    <style jsx>{`
      @keyframes diceRoll {
        0% { transform: rotateX(0deg) rotateY(0deg) rotateZ(0deg) scale(1.3); }
        25% { transform: rotateX(90deg) rotateY(45deg) rotateZ(180deg) scale(1.4); }
        50% { transform: rotateX(180deg) rotateY(90deg) rotateZ(270deg) scale(1.2); }
        75% { transform: rotateX(270deg) rotateY(135deg) rotateZ(360deg) scale(1.5); }
        100% { transform: rotateX(360deg) rotateY(180deg) rotateZ(180deg) scale(1.3); }
      }
    `}</style>
  </div>
);
```

};

const rollDice = () => {
return Math.floor(Math.random() * 6) + 1;
};

const startGame = () => {
setPlayerDice(null);
setComputerDice(null);
setGameResult(’’);
setIsRolling(false);
setRollingValue(1);
setGameState(‘playerRoll’);
setTotalPlays(prev => prev + 1);
};

const rollPlayerDice = () => {
setIsRolling(true);
let rollCount = 0;
const maxRolls = 20; // アニメーション回数を増やしてよりリアルに

```
const rollAnimation = setInterval(() => {
  setRollingValue(Math.floor(Math.random() * 6) + 1);
  rollCount++;
  
  if (rollCount >= maxRolls) {
    clearInterval(rollAnimation);
    const finalResult = rollDice();
    setPlayerDice(finalResult);
    setRollingValue(finalResult);
    setIsRolling(false);
    
    // 少し待ってから次の状態に移行
    setTimeout(() => {
      setGameState('computerRoll');
    }, 1000);
  }
}, 80); // 少し速くして滑らかに
```

};

const rollComputerDice = () => {
setIsRolling(true);
let rollCount = 0;
const maxRolls = 20; // アニメーション回数を増やしてよりリアルに

```
const rollAnimation = setInterval(() => {
  setRollingValue(Math.floor(Math.random() * 6) + 1);
  rollCount++;
  
  if (rollCount >= maxRolls) {
    clearInterval(rollAnimation);
    const finalResult = rollDice();
    setComputerDice(finalResult);
    setRollingValue(finalResult);
    setIsRolling(false);
    
    // 勝敗判定
    let resultMessage = '';
    if (playerDice > finalResult) {
      resultMessage = 'おめでとう！あなたの勝ちです！';
      setWins(prev => prev + 1);
    } else if (playerDice < finalResult) {
      resultMessage = '残念！コンピュータの勝ちです！';
    } else {
      resultMessage = '引き分けです！';
      setDraws(prev => prev + 1);
    }
    
    setGameResult(resultMessage);
    
    // 結果表示まで少し待つ
    setTimeout(() => {
      setGameState('result');
    }, 1000);
  }
}, 80); // 少し速くして滑らかに
```

};

const showStats = () => {
setGameState(‘stats’);
};

const backToStart = () => {
setGameState(‘start’);
};

const winRate = totalPlays > 0 ? ((wins / totalPlays) * 100).toFixed(2) : 0;

return (
<div className="min-h-screen bg-black text-white p-8 font-mono">
<div className="max-w-2xl mx-auto">

```
    {/* ヘッダー */}
    <div className="text-center mb-8">
      <div className="border-2 border-yellow-400 p-4 rounded">
        <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
        <h1 className="text-xl text-yellow-400 mb-2">║     サイコロバトルゲーム       ║</h1>
        <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
      </div>
    </div>

    {/* スタート画面 */}
    {gameState === 'start' && (
      <div className="text-center">
        <p className="text-cyan-400 mb-8 text-lg">
          あなたとコンピュータがサイコロを振り、数字が大きい方が勝ちです！
        </p>
        
        <div className="mb-8">
          <DiceDisplay number={6} color="text-blue-400" bgColor="border-blue-400" />
          <span className="mx-8 text-4xl text-white">VS</span>
          <DiceDisplay number={1} color="text-red-400" bgColor="border-red-400" />
        </div>

        <div className="space-y-4">
          <button 
            onClick={startGame}
            className="bg-yellow-600 hover:bg-yellow-700 text-white font-bold py-3 px-6 rounded text-lg"
          >
            ゲームを始める
          </button>
          
          {totalPlays > 0 && (
            <div>
              <button 
                onClick={showStats}
                className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded ml-4"
              >
                統計を見る
              </button>
            </div>
          )}
        </div>
      </div>
    )}

    {/* プレイヤーのサイコロを振る */}
    {gameState === 'playerRoll' && (
      <div className="text-center">
        <p className="text-yellow-400 mb-6 text-lg">
          {isRolling ? '🎲 サイコロを激しく振っています... 🎲' : 'サイコロを振ります。準備はいいですか？'}
        </p>
        
        <div className="mb-8 flex justify-center">
          <div className={`transition-all duration-300 ${isRolling ? 'transform scale-110' : ''}`}>
            <DiceDisplay 
              number={isRolling ? rollingValue : Math.floor(Math.random() * 6) + 1} 
              color={isRolling ? "text-blue-400" : "text-gray-500"} 
              bgColor={isRolling ? "border-blue-400" : "border-gray-500"}
              isAnimating={isRolling}
            />
          </div>
        </div>

        {!isRolling && (
          <button 
            onClick={rollPlayerDice}
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded text-lg animate-pulse transform hover:scale-105 transition-all"
          >
            🎲 あなたのサイコロを振る 🎲
          </button>
        )}
        
        {isRolling && (
          <div className="space-y-2">
            <div className="text-blue-400 text-xl animate-pulse font-bold">
              ガラガラガラ... 🌪️
            </div>
            <div className="text-sm text-blue-300 animate-bounce">
              どの目が出るかな？
            </div>
          </div>
        )}
      </div>
    )}

    {/* コンピュータのサイコロを振る */}
    {gameState === 'computerRoll' && (
      <div className="text-center">
        <p className="text-blue-400 mb-4 text-lg">あなたのサイコロ:</p>
        <div className="mb-8">
          <DiceDisplay number={playerDice} color="text-blue-400" bgColor="border-blue-400" />
        </div>

        <p className="text-red-400 mb-4 text-lg">
          {isRolling ? '🤖 コンピュータが激しくサイコロを振っています... 🎲' : 'コンピュータのサイコロ:'}
        </p>
        <div className="mb-8 flex justify-center">
          <div className={`transition-all duration-300 ${isRolling ? 'transform scale-110' : ''}`}>
            <DiceDisplay 
              number={isRolling ? rollingValue : Math.floor(Math.random() * 6) + 1} 
              color={isRolling ? "text-red-400" : "text-gray-500"} 
              bgColor={isRolling ? "border-red-400" : "border-gray-500"}
              isAnimating={isRolling}
            />
          </div>
        </div>

        {!isRolling && (
          <button 
            onClick={rollComputerDice}
            className="bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-6 rounded text-lg animate-pulse transform hover:scale-105 transition-all"
          >
            🤖 コンピュータのサイコロを振る 🎲
          </button>
        )}
        
        {isRolling && (
          <div className="space-y-2">
            <div className="text-red-400 text-xl animate-pulse font-bold">
              ウィーン... ガラガラガラ... ⚡
            </div>
            <div className="text-sm text-red-300 animate-bounce">
              AIが計算中... でも運次第！
            </div>
          </div>
        )}
      </div>
    )}

    {/* 結果表示 */}
    {gameState === 'result' && (
      <div className="text-center">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-center mb-8">
          <div>
            <p className="text-blue-400 mb-4 text-lg">あなたのサイコロ:</p>
            <DiceDisplay number={playerDice} color="text-blue-400" bgColor="border-blue-400" />
            <p className="text-blue-400 mt-2 text-2xl font-bold">{playerDice}</p>
          </div>
          
          <div className="text-4xl text-white font-bold">
            VS
          </div>
          
          <div>
            <p className="text-red-400 mb-4 text-lg">コンピュータのサイコロ:</p>
            <DiceDisplay number={computerDice} color="text-red-400" bgColor="border-red-400" />
            <p className="text-red-400 mt-2 text-2xl font-bold">{computerDice}</p>
          </div>
        </div>

        <p className={`text-2xl font-bold mb-8 ${
          gameResult.includes('あなたの勝ち') ? 'text-green-400' : 
          gameResult.includes('コンピュータの勝ち') ? 'text-red-400' : 'text-yellow-400'
        }`}>
          {gameResult}
        </p>

        <div className="space-y-4">
          <button 
            onClick={startGame}
            className="bg-yellow-600 hover:bg-yellow-700 text-white font-bold py-2 px-4 rounded"
          >
            もう一度プレイ
          </button>
          
          <button 
            onClick={backToStart}
            className="bg-gray-600 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded ml-4"
          >
            メニューに戻る
          </button>
        </div>
      </div>
    )}

    {/* 統計画面 */}
    {gameState === 'stats' && (
      <div className="text-center">
        <div className="border-2 border-yellow-400 p-4 mb-8 rounded">
          <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
          <h1 className="text-xl text-yellow-400 mb-2">║         ゲーム統計           ║</h1>
          <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
        </div>

        <div className="bg-gray-900 p-8 rounded-lg mb-8">
          <div className="grid grid-cols-2 gap-8 text-left">
            <div className="space-y-4">
              <p className="text-cyan-400 text-lg">
                総プレイ回数: <span className="text-white font-bold">{totalPlays}</span>
              </p>
              <p className="text-cyan-400 text-lg">
                勝利回数: <span className="text-green-400 font-bold">{wins}</span>
              </p>
            </div>
            <div className="space-y-4">
              <p className="text-cyan-400 text-lg">
                引き分け: <span className="text-yellow-400 font-bold">{draws}</span>
              </p>
              <p className="text-cyan-400 text-lg">
                勝率: <span className="text-white font-bold">{winRate}%</span>
              </p>
            </div>
          </div>
        </div>

        <button 
          onClick={backToStart}
          className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          メニューに戻る
        </button>
      </div>
    )}
  </div>
</div>
```

);
};

export default DiceBattleGame;