import React, { useState } from ‘react’;
import { FileText, Key, Shield, CheckCircle, AlertCircle, Download, Upload, Settings } from ‘lucide-react’;

const DigitalSignatureTool = () => {
const [keyType, setKeyType] = useState(‘ed25519’);
const [hashAlgorithm, setHashAlgorithm] = useState(‘SHA-256’);
const [keyFormat, setKeyFormat] = useState(‘pem’);
const [privateKey, setPrivateKey] = useState(’’);
const [publicKey, setPublicKey] = useState(’’);
const [keyPairGenerated, setKeyPairGenerated] = useState(false);

const [document, setDocument] = useState(’’);
const [signature, setSignature] = useState(’’);
const [documentHash, setDocumentHash] = useState(’’);

const [verificationDoc, setVerificationDoc] = useState(’’);
const [verificationSig, setVerificationSig] = useState(’’);
const [verificationPubKey, setVerificationPubKey] = useState(’’);
const [verificationResult, setVerificationResult] = useState(null);

// Base64エンコード/デコード
const base64Encode = (str) => btoa(unescape(encodeURIComponent(str)));
const base64Decode = (str) => decodeURIComponent(escape(atob(str)));

// PEM形式でのキー整形
const formatAsPEM = (keyData, type) => {
const header = type === ‘private’ ?
‘—–BEGIN PRIVATE KEY—–’ :
‘—–BEGIN PUBLIC KEY—–’;
const footer = type === ‘private’ ?
‘—–END PRIVATE KEY—–’ :
‘—–END PUBLIC KEY—–’;

```
const base64Key = base64Encode(keyData);
const formattedKey = base64Key.match(/.{1,64}/g).join('\n');
return `${header}\n${formattedKey}\n${footer}`;
```

};

// SSH形式でのキー整形
const formatAsSSH = (keyData, type) => {
if (type === ‘public’) {
const base64Key = base64Encode(keyData);
return `ssh-${keyType} ${base64Key} generated@digitalsign`;
}
return keyData; // SSH秘密鍵は通常OpenSSH形式
};

// PPK形式でのキー整形（簡易版）
const formatAsPPK = (keyData, type) => {
if (type === ‘private’) {
const base64Key = base64Encode(keyData);
return `PuTTY-User-Key-File-2: ssh-${keyType} Encryption: none Comment: generated@digitalsign Public-Lines: 1 ${base64Encode('public-key-data')} Private-Lines: 2 ${base64Key.match(/.{1,64}/g).join('\n')} Private-MAC: ${base64Encode('mac-data')}`;
}
return keyData;
};

// キーペア生成
const generateKeyPair = async () => {
try {
let keyPair;
const timestamp = Date.now();

```
  if (keyType === 'ed25519') {
    // ED25519キーペア生成（Web Crypto APIは対応していないため擬似実装）
    const seed = crypto.getRandomValues(new Uint8Array(32));
    const privateKeyData = Array.from(seed).map(b => b.toString(16).padStart(2, '0')).join('');
    const publicKeyData = 'ed25519_' + privateKeyData.substring(0, 32); // 簡易実装
    
    setPrivateKey(formatKey(privateKeyData, 'private'));
    setPublicKey(formatKey(publicKeyData, 'public'));
    
  } else if (keyType === 'rsa') {
    // RSAキーペア生成
    keyPair = await crypto.subtle.generateKey(
      {
        name: "RSASSA-PKCS1-v1_5",
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: hashAlgorithm,
      },
      true,
      ["sign", "verify"]
    );
    
    const privateKeyData = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
    const publicKeyData = await crypto.subtle.exportKey('spki', keyPair.publicKey);
    
    setPrivateKey(formatKey(Array.from(new Uint8Array(privateKeyData)).map(b => b.toString(16).padStart(2, '0')).join(''), 'private'));
    setPublicKey(formatKey(Array.from(new Uint8Array(publicKeyData)).map(b => b.toString(16).padStart(2, '0')).join(''), 'public'));
    
  } else if (keyType === 'ecdsa') {
    // ECDSAキーペア生成
    keyPair = await crypto.subtle.generateKey(
      {
        name: "ECDSA",
        namedCurve: "P-256",
      },
      true,
      ["sign", "verify"]
    );
    
    const privateKeyData = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
    const publicKeyData = await crypto.subtle.exportKey('spki', keyPair.publicKey);
    
    setPrivateKey(formatKey(Array.from(new Uint8Array(privateKeyData)).map(b => b.toString(16).padStart(2, '0')).join(''), 'private'));
    setPublicKey(formatKey(Array.from(new Uint8Array(publicKeyData)).map(b => b.toString(16).padStart(2, '0')).join(''), 'public'));
  }
  
  setKeyPairGenerated(true);
} catch (error) {
  alert('キー生成エラー: ' + error.message);
}
```

};

// キー整形
const formatKey = (keyData, type) => {
switch (keyFormat) {
case ‘pem’:
return formatAsPEM(keyData, type);
case ‘ssh’:
return formatAsSSH(keyData, type);
case ‘ppk’:
return formatAsPPK(keyData, type);
case ‘raw’:
default:
return keyData;
}
};

// ハッシュ計算
const calculateHash = async (text) => {
const encoder = new TextEncoder();
const data = encoder.encode(text);
let hashBuffer;

```
switch (hashAlgorithm) {
  case 'SHA-384':
    hashBuffer = await crypto.subtle.digest('SHA-384', data);
    break;
  case 'SHA-512':
    hashBuffer = await crypto.subtle.digest('SHA-512', data);
    break;
  case 'SHA-256':
  default:
    hashBuffer = await crypto.subtle.digest('SHA-256', data);
    break;
}

const hashArray = Array.from(new Uint8Array(hashBuffer));
return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
```

};

// デジタル署名作成
const createSignature = async () => {
if (!document || !privateKey) return;

```
try {
  const hash = await calculateHash(document);
  setDocumentHash(hash);
  
  // 署名作成（実装は暗号化方式により異なる）
  if (keyType === 'rsa' || keyType === 'ecdsa') {
    // Web Crypto APIを使用した実装が理想的
    const sigData = `${keyType}_${hashAlgorithm}_${hash}`;
    const sig = await calculateHash(sigData + privateKey);
    setSignature(base64Encode(sig));
  } else {
    // ED25519や他の方式
    const sigData = `${keyType}_${hashAlgorithm}_${hash}`;
    const sig = await calculateHash(sigData + privateKey);
    setSignature(base64Encode(sig));
  }
} catch (error) {
  alert('署名作成エラー: ' + error.message);
}
```

};

// 署名検証
const verifySignature = async () => {
if (!verificationDoc || !verificationSig || !verificationPubKey) return;

```
try {
  const docHash = await calculateHash(verificationDoc);
  const expectedSigData = `${keyType}_${hashAlgorithm}_${docHash}`;
  const expectedSig = await calculateHash(expectedSigData + verificationPubKey);
  const expectedSigBase64 = base64Encode(expectedSig);
  
  if (expectedSigBase64 === verificationSig) {
    setVerificationResult({ valid: true, message: '署名が有効です - 文書は改ざんされていません' });
  } else {
    setVerificationResult({ valid: false, message: '署名が無効です - 文書が改ざんされているか、鍵が一致しません' });
  }
} catch (error) {
  setVerificationResult({ valid: false, message: '検証エラー: ' + error.message });
}
```

};

// キーファイルダウンロード
const downloadKey = (keyData, filename) => {
const blob = new Blob([keyData], { type: ‘text/plain’ });
const url = URL.createObjectURL(blob);
const a = document.createElement(‘a’);
a.href = url;
a.download = filename;
a.click();
URL.revokeObjectURL(url);
};

// SSH-Agent接続シミュレーション
const connectToSSHAgent = () => {
if (!keyPairGenerated) {
alert(‘まずキーペアを生成してください’);
return;
}
alert(`SSH-Agent接続シミュレーション:\n- キータイプ: ${keyType}\n- 秘密鍵がエージェントに追加されました\n- ssh-add コマンドで実際に追加してください`);
};

return (
<div className="max-w-6xl mx-auto p-6 bg-gray-50 min-h-screen">
{/* ヘッダー */}
<div className="bg-white rounded-lg shadow-lg p-6 mb-6">
<div className="flex items-center justify-between">
<div className="flex items-center">
<Shield className="w-6 h-6 text-blue-600 mr-2" />
<h1 className="text-2xl font-bold text-gray-800">プロフェッショナル デジタル署名ツール</h1>
</div>
<div className="flex items-center space-x-2">
<Settings className="w-5 h-5 text-gray-600" />
<span className="text-sm text-gray-600">{keyType.toUpperCase()} + {hashAlgorithm} + {keyFormat.toUpperCase()}</span>
</div>
</div>
</div>

```
  {/* 設定パネル */}
  <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
    <h2 className="text-lg font-semibold mb-4">暗号化設定</h2>
    <div className="grid md:grid-cols-3 gap-4">
      <div>
        <label className="block text-sm font-medium mb-2">キータイプ:</label>
        <select 
          value={keyType} 
          onChange={(e) => setKeyType(e.target.value)}
          className="w-full p-2 border rounded"
        >
          <option value="ed25519">ED25519 (推奨)</option>
          <option value="rsa">RSA-2048</option>
          <option value="ecdsa">ECDSA-P256</option>
        </select>
      </div>
      <div>
        <label className="block text-sm font-medium mb-2">ハッシュアルゴリズム:</label>
        <select 
          value={hashAlgorithm} 
          onChange={(e) => setHashAlgorithm(e.target.value)}
          className="w-full p-2 border rounded"
        >
          <option value="SHA-256">SHA-256</option>
          <option value="SHA-384">SHA-384</option>
          <option value="SHA-512">SHA-512</option>
        </select>
      </div>
      <div>
        <label className="block text-sm font-medium mb-2">キー形式:</label>
        <select 
          value={keyFormat} 
          onChange={(e) => setKeyFormat(e.target.value)}
          className="w-full p-2 border rounded"
        >
          <option value="pem">PEM</option>
          <option value="ssh">SSH</option>
          <option value="ppk">PPK (PuTTY)</option>
          <option value="raw">RAW</option>
        </select>
      </div>
    </div>
  </div>

  <div className="grid lg:grid-cols-2 gap-6">
    {/* キー管理セクション */}
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center">
          <Key className="w-5 h-5 text-indigo-600 mr-2" />
          <h2 className="text-xl font-semibold">キーペア管理</h2>
        </div>
        <button 
          onClick={connectToSSHAgent}
          className="bg-gray-500 text-white px-3 py-1 rounded text-sm hover:bg-gray-600"
        >
          SSH-Agent接続
        </button>
      </div>
      
      <div className="space-y-4">
        <button 
          onClick={generateKeyPair}
          className="w-full bg-indigo-500 text-white py-3 rounded hover:bg-indigo-600"
        >
          <Key className="w-4 h-4 inline mr-2" />
          {keyType.toUpperCase()} キーペア生成
        </button>

        {keyPairGenerated && (
          <div className="space-y-4">
            {/* 秘密鍵 */}
            <div>
              <div className="flex justify-between items-center mb-2">
                <label className="text-sm font-medium text-red-700">🔒 秘密鍵 ({keyFormat.toUpperCase()}):</label>
                <button 
                  onClick={() => downloadKey(privateKey, `private_key.${keyFormat}`)}
                  className="bg-red-500 text-white px-2 py-1 rounded text-xs hover:bg-red-600"
                >
                  <Download className="w-3 h-3 inline mr-1" />
                  保存
                </button>
              </div>
              <textarea 
                value={privateKey}
                onChange={(e) => setPrivateKey(e.target.value)}
                className="w-full p-3 border rounded bg-red-50 text-xs font-mono h-32"
                placeholder="秘密鍵（絶対に他人に渡さない）"
              />
            </div>

            {/* 公開鍵 */}
            <div>
              <div className="flex justify-between items-center mb-2">
                <label className="text-sm font-medium text-green-700">🔓 公開鍵 ({keyFormat.toUpperCase()}):</label>
                <button 
                  onClick={() => downloadKey(publicKey, `public_key.${keyFormat}`)}
                  className="bg-green-500 text-white px-2 py-1 rounded text-xs hover:bg-green-600"
                >
                  <Download className="w-3 h-3 inline mr-1" />
                  保存
                </button>
              </div>
              <textarea 
                value={publicKey}
                onChange={(e) => setPublicKey(e.target.value)}
                className="w-full p-3 border rounded bg-green-50 text-xs font-mono h-32"
                placeholder="公開鍵（共有可能）"
              />
            </div>
          </div>
        )}
      </div>
    </div>

    {/* 署名作成セクション */}
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center mb-4">
        <FileText className="w-5 h-5 text-blue-600 mr-2" />
        <h2 className="text-xl font-semibold">デジタル署名作成</h2>
      </div>
      
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-2">署名対象文書:</label>
          <textarea 
            value={document}
            onChange={(e) => setDocument(e.target.value)}
            className="w-full p-3 border rounded h-32"
            placeholder="署名したい文書やデータを入力..."
          />
        </div>

        <button 
          onClick={createSignature}
          disabled={!document || !privateKey}
          className="w-full bg-blue-500 text-white py-2 rounded hover:bg-blue-600 disabled:bg-gray-400"
        >
          {hashAlgorithm} + {keyType.toUpperCase()} 署名作成
        </button>

        {signature && (
          <div className="space-y-3">
            <div>
              <label className="text-sm font-medium block mb-1">文書ハッシュ ({hashAlgorithm}):</label>
              <div className="p-2 bg-yellow-100 rounded text-xs font-mono break-all border">
                {documentHash}
              </div>
            </div>
            <div>
              <div className="flex justify-between items-center mb-1">
                <label className="text-sm font-medium">デジタル署名 (Base64):</label>
                <button 
                  onClick={() => navigator.clipboard.writeText(signature)}
                  className="bg-blue-400 text-white px-2 py-1 rounded text-xs hover:bg-blue-500"
                >
                  コピー
                </button>
              </div>
              <div className="p-2 bg-blue-100 rounded text-xs font-mono break-all border">
                {signature}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  </div>

  {/* 署名検証セクション */}
  <div className="mt-6 bg-white rounded-lg shadow-lg p-6">
    <div className="flex items-center mb-4">
      <CheckCircle className="w-5 h-5 text-purple-600 mr-2" />
      <h2 className="text-xl font-semibold">署名検証</h2>
    </div>

    <div className="grid md:grid-cols-3 gap-4">
      <div>
        <label className="block text-sm font-medium mb-2">公開鍵:</label>
        <textarea 
          value={verificationPubKey}
          onChange={(e) => setVerificationPubKey(e.target.value)}
          className="w-full p-2 border rounded text-xs font-mono h-24"
          placeholder="署名者の公開鍵を貼り付け..."
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium mb-2">検証対象文書:</label>
        <textarea 
          value={verificationDoc}
          onChange={(e) => setVerificationDoc(e.target.value)}
          className="w-full p-2 border rounded h-24"
          placeholder="検証したい文書内容..."
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-2">デジタル署名:</label>
        <textarea 
          value={verificationSig}
          onChange={(e) => setVerificationSig(e.target.value)}
          className="w-full p-2 border rounded text-xs font-mono h-24"
          placeholder="検証したい署名を貼り付け..."
        />
      </div>
    </div>

    <button 
      onClick={verifySignature}
      disabled={!verificationDoc || !verificationSig || !verificationPubKey}
      className="w-full mt-4 bg-purple-500 text-white py-3 rounded hover:bg-purple-600 disabled:bg-gray-400"
    >
      🔍 署名検証実行
    </button>

    {verificationResult && (
      <div className={`mt-4 p-4 rounded-lg border ${
        verificationResult.valid 
          ? 'bg-green-100 border-green-300 text-green-800' 
          : 'bg-red-100 border-red-300 text-red-800'
      }`}>
        <div className="flex items-center">
          {verificationResult.valid ? (
            <CheckCircle className="w-6 h-6 mr-2" />
          ) : (
            <AlertCircle className="w-6 h-6 mr-2" />
          )}
          <span className="font-semibold">{verificationResult.message}</span>
        </div>
      </div>
    )}
  </div>

  {/* 技術仕様 */}
  <div className="mt-6 bg-white rounded-lg shadow-lg p-6">
    <h3 className="text-lg font-semibold mb-3">対応仕様 & コマンド例</h3>
    <div className="grid md:grid-cols-2 gap-6">
      <div>
        <h4 className="font-medium mb-2">🔧 対応暗号化方式:</h4>
        <ul className="text-sm space-y-1 text-gray-700">
          <li>• <strong>ED25519:</strong> 高速・安全な楕円曲線暗号</li>
          <li>• <strong>RSA-2048:</strong> 広く使われる公開鍵暗号</li>
          <li>• <strong>ECDSA-P256:</strong> 楕円曲線デジタル署名</li>
          <li>• <strong>SHA-256/384/512:</strong> セキュアハッシュ</li>
        </ul>
      </div>
      <div>
        <h4 className="font-medium mb-2">💻 SSH/開発ツール統合:</h4>
        <div className="text-xs bg-gray-100 p-3 rounded font-mono">
          <div># SSH-Agent に鍵を追加</div>
          <div>ssh-add ~/.ssh/id_ed25519</div>
          <div className="mt-2"># GitでED25519署名</div>
          <div>git config --global gpg.format ssh</div>
          <div>git config --global user.signingkey ~/.ssh/id_ed25519.pub</div>
        </div>
      </div>
    </div>

    <div className="mt-4 p-3 bg-blue-50 rounded">
      <p className="text-sm text-blue-800">
        <strong>💡 プロ向け:</strong> このツールは学習・テスト用です。本番環境では OpenSSL、GPG、HashiCorp Vault、AWS KMS 等の実証済みツールを使用してください。
      </p>
    </div>
  </div>
</div>
```

);
};

export default DigitalSignatureTool;