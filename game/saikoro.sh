import React, { useState, useEffect } from ‘react’;

const DiceBattleGame = () => {
const [gameState, setGameState] = useState(‘start’); // ‘start’, ‘playerRoll’, ‘computerRoll’, ‘result’, ‘stats’
const [playerDice, setPlayerDice] = useState(null);
const [computerDice, setComputerDice] = useState(null);
const [totalPlays, setTotalPlays] = useState(0);
const [wins, setWins] = useState(0);
const [draws, setDraws] = useState(0);
const [gameResult, setGameResult] = useState(’’);

// サイコロの目を表示するコンポーネント
const DiceDisplay = ({ number, color = ‘text-white’, bgColor = ‘border-white’ }) => {
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
  <div className={`inline-block border-4 ${bgColor} p-4 rounded-lg bg-gray-900`}>
    <div className="font-mono text-2xl leading-tight">
      {pattern.map((row, rowIndex) => (
        <div key={rowIndex} className="flex justify-center space-x-2">
          {row.map((cell, cellIndex) => (
            <div key={cellIndex} className={`w-6 h-6 flex items-center justify-center ${color}`}>
              {cell}
            </div>
          ))}
        </div>
      ))}
    </div>
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
setGameState(‘playerRoll’);
setTotalPlays(prev => prev + 1);
};

const rollPlayerDice = () => {
const result = rollDice();
setPlayerDice(result);
setGameState(‘computerRoll’);
};

const rollComputerDice = () => {
const result = rollDice();
setComputerDice(result);

```
// 勝敗判定
let resultMessage = '';
if (playerDice > result) {
  resultMessage = 'おめでとう！あなたの勝ちです！';
  setWins(prev => prev + 1);
} else if (playerDice < result) {
  resultMessage = '残念！コンピュータの勝ちです！';
} else {
  resultMessage = '引き分けです！';
  setDraws(prev => prev + 1);
}

setGameResult(resultMessage);
setGameState('result');
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
          サイコロを振ります。準備はいいですか？
        </p>
        
        <div className="mb-8">
          <DiceDisplay number={Math.floor(Math.random() * 6) + 1} color="text-gray-500" bgColor="border-gray-500" />
        </div>

        <button 
          onClick={rollPlayerDice}
          className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded text-lg animate-pulse"
        >
          あなたのサイコロを振る
        </button>
      </div>
    )}

    {/* コンピュータのサイコロを振る */}
    {gameState === 'computerRoll' && (
      <div className="text-center">
        <p className="text-blue-400 mb-4 text-lg">あなたのサイコロ:</p>
        <div className="mb-8">
          <DiceDisplay number={playerDice} color="text-blue-400" bgColor="border-blue-400" />
        </div>

        <div className="mb-8">
          <DiceDisplay number={Math.floor(Math.random() * 6) + 1} color="text-gray-500" bgColor="border-gray-500" />
        </div>

        <button 
          onClick={rollComputerDice}
          className="bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-6 rounded text-lg animate-pulse"
        >
          コンピュータのサイコロを振る
        </button>
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