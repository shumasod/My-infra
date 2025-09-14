import React, { useState } from ‘react’;
import { FileText, Key, Shield, CheckCircle, AlertCircle } from ‘lucide-react’;

const DigitalSignatureTool = () => {
const [document, setDocument] = useState(’’);
const [privateKey, setPrivateKey] = useState(’’);
const [publicKey, setPublicKey] = useState(’’);
const [signature, setSignature] = useState(’’);
const [verificationDoc, setVerificationDoc] = useState(’’);
const [verificationSig, setVerificationSig] = useState(’’);
const [verificationResult, setVerificationResult] = useState(null);
const [documentHash, setDocumentHash] = useState(’’);

// 簡単なハッシュ関数（実際のプロジェクトではCrypto APIを使用）
const simpleHash = async (text) => {
const encoder = new TextEncoder();
const data = encoder.encode(text);
const hashBuffer = await crypto.subtle.digest(‘SHA-256’, data);
const hashArray = Array.from(new Uint8Array(hashBuffer));
return hashArray.map(b => b.toString(16).padStart(2, ‘0’)).join(’’);
};

// 簡易的な署名作成（実際の実装ではRSAやECDSAを使用）
const createSignature = async () => {
if (!document || !privateKey) return;

```
const hash = await simpleHash(document);
setDocumentHash(hash);

// 簡易的な署名（実際は暗号化）
const sigData = `${hash}-${privateKey}`;
const sig = await simpleHash(sigData);
setSignature(sig);
```

};

// 署名検証
const verifySignature = async () => {
if (!verificationDoc || !verificationSig || !publicKey) return;

```
const docHash = await simpleHash(verificationDoc);
const expectedSig = await simpleHash(`${docHash}-${publicKey}`);

if (expectedSig === verificationSig) {
  setVerificationResult({ valid: true, message: '署名が有効です' });
} else {
  setVerificationResult({ valid: false, message: '署名が無効です' });
}
```

};

// キーペア生成（簡易版）
const generateKeyPair = () => {
const timestamp = Date.now().toString();
const random = Math.random().toString(36);
setPrivateKey(`priv_${timestamp}_${random}`);
setPublicKey(`pub_${timestamp}_${random}`);
};

return (
<div className="max-w-4xl mx-auto p-6 bg-gray-50 min-h-screen">
<div className="bg-white rounded-lg shadow-lg p-6 mb-6">
<div className="flex items-center mb-4">
<Shield className="w-6 h-6 text-blue-600 mr-2" />
<h1 className="text-2xl font-bold text-gray-800">デジタル署名作成ツール</h1>
</div>
<p className="text-gray-600 mb-6">
文書の真正性と完全性を保証するデジタル署名を作成・検証できます
</p>
</div>

```
  <div className="grid md:grid-cols-2 gap-6">
    {/* 署名作成セクション */}
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center mb-4">
        <FileText className="w-5 h-5 text-green-600 mr-2" />
        <h2 className="text-xl font-semibold">署名作成</h2>
      </div>
      
      {/* キーペア生成 */}
      <div className="mb-4">
        <button 
          onClick={generateKeyPair}
          className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 mb-3"
        >
          <Key className="w-4 h-4 inline mr-2" />
          キーペア生成
        </button>
        
        {privateKey && (
          <div className="space-y-2">
            <div>
              <label className="block text-sm font-medium mb-1">秘密鍵:</label>
              <input 
                type="text" 
                value={privateKey}
                onChange={(e) => setPrivateKey(e.target.value)}
                className="w-full p-2 border rounded text-xs bg-red-50"
                placeholder="秘密鍵（安全に保管してください）"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">公開鍵:</label>
              <input 
                type="text" 
                value={publicKey}
                onChange={(e) => setPublicKey(e.target.value)}
                className="w-full p-2 border rounded text-xs bg-green-50"
                placeholder="公開鍵（共有可能）"
              />
            </div>
          </div>
        )}
      </div>

      {/* 文書入力 */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">署名対象文書:</label>
        <textarea 
          value={document}
          onChange={(e) => setDocument(e.target.value)}
          className="w-full p-3 border rounded h-32"
          placeholder="署名したい文書の内容を入力してください"
        />
      </div>

      <button 
        onClick={createSignature}
        disabled={!document || !privateKey}
        className="w-full bg-green-500 text-white py-2 rounded hover:bg-green-600 disabled:bg-gray-400"
      >
        署名作成
      </button>

      {/* 結果表示 */}
      {signature && (
        <div className="mt-4 space-y-3">
          <div>
            <label className="block text-sm font-medium mb-1">文書ハッシュ:</label>
            <div className="p-2 bg-gray-100 rounded text-xs font-mono break-all">
              {documentHash}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">デジタル署名:</label>
            <div className="p-2 bg-blue-100 rounded text-xs font-mono break-all">
              {signature}
            </div>
          </div>
        </div>
      )}
    </div>

    {/* 署名検証セクション */}
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center mb-4">
        <CheckCircle className="w-5 h-5 text-purple-600 mr-2" />
        <h2 className="text-xl font-semibold">署名検証</h2>
      </div>

      {/* 公開鍵入力 */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">公開鍵:</label>
        <input 
          type="text" 
          value={publicKey}
          onChange={(e) => setPublicKey(e.target.value)}
          className="w-full p-2 border rounded text-xs"
          placeholder="署名者の公開鍵"
        />
      </div>

      {/* 検証文書入力 */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">検証対象文書:</label>
        <textarea 
          value={verificationDoc}
          onChange={(e) => setVerificationDoc(e.target.value)}
          className="w-full p-3 border rounded h-24"
          placeholder="検証したい文書の内容"
        />
      </div>

      {/* 署名入力 */}
      <div className="mb-4">
        <label className="block text-sm font-medium mb-2">デジタル署名:</label>
        <input 
          type="text" 
          value={verificationSig}
          onChange={(e) => setVerificationSig(e.target.value)}
          className="w-full p-2 border rounded text-xs"
          placeholder="検証したい署名"
        />
      </div>

      <button 
        onClick={verifySignature}
        disabled={!verificationDoc || !verificationSig || !publicKey}
        className="w-full bg-purple-500 text-white py-2 rounded hover:bg-purple-600 disabled:bg-gray-400"
      >
        署名検証
      </button>

      {/* 検証結果 */}
      {verificationResult && (
        <div className={`mt-4 p-3 rounded flex items-center ${
          verificationResult.valid ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
        }`}>
          {verificationResult.valid ? (
            <CheckCircle className="w-5 h-5 mr-2" />
          ) : (
            <AlertCircle className="w-5 h-5 mr-2" />
          )}
          {verificationResult.message}
        </div>
      )}
    </div>
  </div>

  {/* 説明セクション */}
  <div className="mt-6 bg-white rounded-lg shadow-lg p-6">
    <h3 className="text-lg font-semibold mb-3">デジタル署名の仕組み</h3>
    <div className="space-y-3 text-sm text-gray-700">
      <div className="flex items-start">
        <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs mr-3 mt-0.5">1</span>
        <div>
          <strong>ハッシュ化:</strong> 文書から固定長のハッシュ値（要約）を生成
        </div>
      </div>
      <div className="flex items-start">
        <span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs mr-3 mt-0.5">2</span>
        <div>
          <strong>暗号化:</strong> ハッシュ値を秘密鍵で暗号化してデジタル署名を作成
        </div>
      </div>
      <div className="flex items-start">
        <span className="bg-purple-100 text-purple-800 px-2 py-1 rounded text-xs mr-3 mt-0.5">3</span>
        <div>
          <strong>検証:</strong> 公開鍵で署名を復号し、文書のハッシュと比較して真正性を確認
        </div>
      </div>
    </div>
    
    <div className="mt-4 p-3 bg-yellow-100 rounded">
      <p className="text-sm text-yellow-800">
        <strong>注意:</strong> これは学習用の簡易実装です。実際のプロダクションでは、RSA、ECDSA等の標準的な暗号アルゴリズムとWeb Crypto APIを使用してください。
      </p>
    </div>
  </div>
</div>
```

);
};

export default DigitalSignatureTool;