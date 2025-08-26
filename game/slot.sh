import React, { useState, useEffect, useCallback } from ‘react’;

const SlotGame = () => {
const [gameState, setGameState] = useState(‘start’); // ‘start’, ‘playing’, ‘result’, ‘stats’
const [cards, setCards] = useState([’?’, ‘?’, ‘?’]);
const [enterCount, setEnterCount] = useState(0);
const [isAnimating, setIsAnimating] = useState(false);
const [totalPlays, setTotalPlays] = useState(0);
const [wins, setWins] = useState(0);
const [showWinAnimation, setShowWinAnimation] = useState(false);
const [message, setMessage] = useState(’’);

const cardSymbols = [‘7’, ‘$’, ‘?’, ‘♠’, ‘♥’, ‘♦’, ‘♣’];

const getRandomCard = () => {
return cardSymbols[Math.floor(Math.random() * cardSymbols.length)];
};

const resetGame = () => {
setCards([’?’, ‘?’, ‘?’]);
setEnterCount(0);
setIsAnimating(false);
setShowWinAnimation(false);
setMessage(’’);
};

const startGame = () => {
resetGame();
setGameState(‘playing’);
setTotalPlays(prev => prev + 1);
};

const checkWin = useCallback((card1, card2, card3) => {
return card1 === card2 && card2 === card3;
}, []);

const getCardColors = (index, card1, card2, card3) => {
if (enterCount === 1 && index === 0) return ‘text-green-400’;
if (enterCount === 2) {
if (card1 === card2 && (index === 0 || index === 1)) return ‘text-blue-400’;
if (index < 2) return ‘text-green-400’;
}
if (enterCount === 3) {
if (checkWin(card1, card2, card3)) return ‘text-yellow-400’;
if ((card1 === card2 && (index === 0 || index === 1)) ||
(card1 === card3 && (index === 0 || index === 2)) ||
(card2 === card3 && (index === 1 || index === 2))) {
return ‘text-blue-400’;
}
return ‘text-green-400’;
}
return ‘text-white’;
};

const processSlot = useCallback(() => {
if (enterCount >= 3) return;

```
const newCards = [...cards];

switch (enterCount) {
  case 0:
    newCards[0] = getRandomCard();
    newCards[1] = getRandomCard();
    newCards[2] = getRandomCard();
    break;
  case 1:
    newCards[1] = getRandomCard();
    newCards[2] = getRandomCard();
    break;
  case 2:
    newCards[2] = getRandomCard();
    break;
}

setCards(newCards);
const newEnterCount = enterCount + 1;
setEnterCount(newEnterCount);

if (newEnterCount === 3) {
  if (checkWin(newCards[0], newCards[1], newCards[2])) {
    setShowWinAnimation(true);
    setWins(prev => prev + 1);
    setMessage('おめでとうございます! 大当たりです！');
  } else {
    setMessage('残念でした!');
  }
  setTimeout(() => {
    setGameState('result');
  }, showWinAnimation ? 2000 : 1000);
}
```

}, [cards, enterCount, checkWin]);

const handleKeyPress = useCallback((e) => {
if (gameState === ‘playing’ && e.code === ‘Enter’ && !isAnimating) {
e.preventDefault();
setIsAnimating(true);
setTimeout(() => {
processSlot();
setIsAnimating(false);
}, 200);
}
}, [gameState, isAnimating, processSlot]);

useEffect(() => {
document.addEventListener(‘keydown’, handleKeyPress);
return () => document.removeEventListener(‘keydown’, handleKeyPress);
}, [handleKeyPress]);

const showStats = () => {
setGameState(‘stats’);
};

const backToStart = () => {
setGameState(‘start’);
};

const winRate = totalPlays > 0 ? ((wins / totalPlays) * 100).toFixed(2) : 0;

const WinAnimation = () => {
const [flash, setFlash] = useState(false);

```
useEffect(() => {
  const interval = setInterval(() => {
    setFlash(prev => !prev);
  }, 200);

  return () => clearInterval(interval);
}, []);

return (
  <div className={`transition-colors duration-200 ${flash ? 'bg-red-900' : ''}`}>
    <div className={`border-4 transition-colors duration-200 p-4 rounded-lg ${
      flash ? 'border-red-400' : 'border-cyan-400'
    }`}>
      <div className="flex justify-center items-center space-x-4 text-4xl font-bold">
        {cards.map((card, index) => (
          <div key={index} className="text-yellow-400">
            |{card}|
          </div>
        ))}
      </div>
    </div>
  </div>
);
```

};

return (
<div className="min-h-screen bg-black text-white p-8 font-mono">
<div className="max-w-md mx-auto">

```
    {gameState === 'start' && (
      <div className="text-center">
        <div className="border-2 border-yellow-400 p-4 mb-8 rounded">
          <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
          <h1 className="text-xl text-yellow-400 mb-2">║     華麗なるスロットゲーム       ║</h1>
          <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
        </div>
        
        <div className="border-4 border-cyan-400 p-4 mb-8 rounded-lg">
          <div className="flex justify-center items-center space-x-4 text-4xl font-bold text-white">
            <div>|?|</div>
            <div>|?|</div>
            <div>|?|</div>
          </div>
        </div>

        <div className="space-y-4">
          <button 
            onClick={startGame}
            className="bg-yellow-600 hover:bg-yellow-700 text-white font-bold py-2 px-4 rounded"
          >
            ゲームを始める
          </button>
          
          {totalPlays > 0 && (
            <button 
              onClick={showStats}
              className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded ml-4"
            >
              統計を見る
            </button>
          )}
        </div>
      </div>
    )}

    {gameState === 'playing' && (
      <div className="text-center">
        <div className="border-2 border-yellow-400 p-4 mb-8 rounded">
          <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
          <h1 className="text-xl text-yellow-400 mb-2">║     華麗なるスロットゲーム       ║</h1>
          <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
        </div>

        {showWinAnimation ? (
          <WinAnimation />
        ) : (
          <div className="border-4 border-cyan-400 p-4 mb-8 rounded-lg">
            <div className="flex justify-center items-center space-x-4 text-4xl font-bold">
              {cards.map((card, index) => (
                <div key={index} className={getCardColors(index, cards[0], cards[1], cards[2])}>
                  |{card}|
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="mb-4">
          <p className="text-magenta-400 mb-2">
            何も入力せずに、Enterキーを押してください!
          </p>
          <p className="text-cyan-400">
            ストップ回数: {enterCount}/3
          </p>
        </div>

        {message && (
          <p className={`text-lg font-bold ${
            message.includes('おめでとう') ? 'text-green-400' : 'text-red-400'
          }`}>
            {message}
          </p>
        )}
      </div>
    )}

    {gameState === 'result' && (
      <div className="text-center">
        <div className="border-2 border-yellow-400 p-4 mb-8 rounded">
          <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
          <h1 className="text-xl text-yellow-400 mb-2">║     華麗なるスロットゲーム       ║</h1>
          <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
        </div>

        <div className="border-4 border-cyan-400 p-4 mb-8 rounded-lg">
          <div className="flex justify-center items-center space-x-4 text-4xl font-bold">
            {cards.map((card, index) => (
              <div key={index} className={getCardColors(index, cards[0], cards[1], cards[2])}>
                |{card}|
              </div>
            ))}
          </div>
        </div>

        <p className={`text-lg font-bold mb-8 ${
          message.includes('おめでとう') ? 'text-green-400' : 'text-red-400'
        }`}>
          {message}
        </p>

        <div className="space-y-4">
          <button 
            onClick={startGame}
            className="bg-yellow-600 hover:bg-yellow-700 text-white font-bold py-2 px-4 rounded"
          >
            もう一度チャレンジ
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

    {gameState === 'stats' && (
      <div className="text-center">
        <div className="border-2 border-yellow-400 p-4 mb-8 rounded">
          <h1 className="text-xl text-yellow-400 mb-2">╔═════════════════════════════════╗</h1>
          <h1 className="text-xl text-yellow-400 mb-2">║         ゲーム統計           ║</h1>
          <h1 className="text-xl text-yellow-400">╚═════════════════════════════════╝</h1>
        </div>

        <div className="bg-gray-900 p-6 rounded-lg mb-8">
          <div className="space-y-4 text-left">
            <p className="text-cyan-400">
              総プレイ回数: <span className="text-white font-bold">{totalPlays}</span>
            </p>
            <p className="text-cyan-400">
              勝利回数: <span className="text-white font-bold">{wins}</span>
            </p>
            <p className="text-cyan-400">
              勝率: <span className="text-white font-bold">{winRate}%</span>
            </p>
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

export default SlotGame;