# GitHub Actions CI/CD Workflows

このディレクトリには、自動化されたテスト・デプロイメントのワークフロー定義が格納されています。

## 📋 ワークフロー一覧

### 1. **ci.yml** — 総合 CI (包括的チェック)

**トリガー条件:**
- `main` または `claude/**` ブランチへの push
- `main` ブランチへの pull request

**実行内容:**
- Flutter アプリの `flutter analyze` & `flutter test`
- Cloud Functions の `npm test`
- Prototype (経路探索エンジン) の検証

**実行時間:** 約 5-10 分

---

### 2. **flutter-analysis-test.yml** — Flutter チェック

**トリガー条件:**
- `app/` ディレクトリ内のファイルが変更された場合

**実行内容:**
1. Flutter SDK をセットアップ
2. `flutter pub get` で依存パッケージをインストール
3. `flutter analyze` でコード解析
4. `flutter test` でユニットテストを実行

**期待される結果:**
- ✅ `flutter analyze` がクリーン (エラーなし)
- ✅ `flutter test` で 48/48 テストが PASS

**失敗時の対応:**
- ログを確認 (`Actions` タブ > 該当ワークフロー)
- ローカルで同じコマンドを実行: `cd app && flutter analyze && flutter test`
- 修正を push

---

### 3. **functions-test.yml** — Cloud Functions テスト

**トリガー条件:**
- `functions/` ディレクトリ内のファイルが変更された場合

**実行内容:**
1. Node.js 20.x をセットアップ
2. `npm ci` で依存パッケージをインストール (ロック版)
3. `npm test` で Cloud Functions のユニットテストを実行
4. `npm audit` でセキュリティ脆弱性をチェック (警告のみ)

**期待される結果:**
- ✅ 全テストが PASS
- ⚠️ `npm audit` は警告止まり (エラーにはしない)

**失敗時の対応:**
- ログを確認
- ローカルで `cd functions && npm test` を実行
- 修正後に push

---

### 4. **prototype-verification.yml** — 経路探索エンジン検証

**トリガー条件:**
- `prototype/` ディレクトリ内のファイルが変更された場合

**実行内容:**
1. Node.js 20.x をセットアップ
2. `npm install` で依存パッケージをインストール
3. `npm run verify` で経路探索エンジンの検証を実行
4. `npm run perf:check` でパフォーマンスチェック (情報のみ)

**期待される結果:**
- ✅ 検証が成功
- 📊 パフォーマンスメトリクスが出力される

---

### 5. **deploy-functions.yml** — Cloud Functions 自動デプロイ

**トリガー条件:**
- `main` ブランチへの push
- `functions/`, `firestore.rules`, `firestore.indexes.json` が変更された場合

**実行内容:**
1. `npm test` で再度テストを実行 (安全弁)
2. Firebase CLI をセットアップ
3. Cloud Functions、Firestore ルール、インデックスを本番環境にデプロイ

**前提条件:**
- GitHub Secrets に以下を設定:
  - `FIREBASE_TOKEN`: Firebase CI トークン
  - `FIREBASE_PROJECT_ID`: 本番 Firebase プロジェクト ID

**⚠️ 重要:**
- このワークフローは **`main` ブランチへのマージ後に自動実行** されます
- デプロイ前に必ず PR レビューと CI テストをパスしてください
- 本番環境へのアクセス許可が `environment: production` で制御されます

---

## 🔐 Firebase Secrets の設定

### FIREBASE_TOKEN 取得方法

```bash
firebase login:ci
```

このコマンドが返すトークンを GitHub Secrets に登録してください。

### GitHub Secrets への登録

1. GitHub リポジトリ > Settings > Secrets and variables > Actions
2. `New repository secret` をクリック
3. 以下を追加:
   - **Name:** `FIREBASE_TOKEN`
   - **Value:** `firebase login:ci` の出力
   - **Name:** `FIREBASE_PROJECT_ID`
   - **Value:** 本番 Firebase プロジェクト ID

### Environment Protection

`deploy-functions.yml` では `environment: production` を指定しており、デプロイ実行前に承認が必要です。

1. Settings > Environments > production を作成
2. Required reviewers を設定 (オプション)
3. Deployment branches を設定: `main` のみ

---

## 📊 ワークフローの実行状況確認

### GitHub UI から確認

1. リポジトリトップ > Actions タブ
2. 左側から実行したいワークフロー名をクリック
3. 実行履歴と詳細ログを確認

### コマンドラインから確認

```bash
gh run list --repo zka32101/project-039
gh run view <run-id> --log
```

---

## 🚀 手動ワークフロー実行

特定のワークフローを手動実行したい場合:

```bash
gh workflow run ci.yml --ref main
gh workflow run deploy-functions.yml --ref main
```

---

## ⚙️ ワークフローのカスタマイズ

### 実行時間を短縮したい

**options:**
- `paths` フィルタを厳しくする (不要な変更で実行されないようにする)
- 並列ジョブを追加 (`jobs` に複数エントリを作成)
- キャッシュを有効化 (`actions/setup-node` で `cache: npm` を指定)

### 追加の検査を追加したい

**examples:**
- Lint: `flutter format --check`, `eslint`
- Coverage: `flutter test --coverage`
- Security scan: `npm audit --audit-level=high`
- Code review bot: `codecov`, `SonarCloud`

### デプロイ前の承認を追加したい

`deploy-functions.yml` の `environment: production` を活用:

```yaml
environment:
  name: production
  url: https://console.firebase.google.com/project/${{ secrets.FIREBASE_PROJECT_ID }}
```

この設定により、デプロイ実行時に GitHub で承認を求めるプロンプトが表示されます。

---

## 📝 トラブルシューティング

### 「Flutter SDK not found」エラー

- `subosito/flutter-action@v2` が最新版か確認
- ワークフロー内で `flutter --version` を実行して確認

**修正:**
```yaml
- name: Check Flutter version
  run: flutter --version
```

### 「npm install timeout」

ネットワークが遅い場合、タイムアウト設定を増やします:

```yaml
- name: Install dependencies
  run: npm ci --prefer-offline
  timeout-minutes: 15
```

### Firebase デプロイ失敗

1. ログの `FIREBASE_TOKEN` エラーを確認
2. Secrets が正しく設定されているか確認
3. トークンの有効期限が切れていないか確認

**トークンリセット:**
```bash
firebase login:ci --no-localhost
```

---

## 🔄 次のステップ

1. **Slack 通知の追加** (デプロイ完了時に通知)
   ```yaml
   - name: Slack Notification
     uses: 8398a7/action-slack@v3
     with:
       webhook_url: ${{ secrets.SLACK_WEBHOOK }}
   ```

2. **OIDC を使った Firebase 認証** (トークン管理を簡略化)
   ```yaml
   permissions:
     id-token: write
   ```

3. **複数環境への デプロイ** (staging → production)
   ```yaml
   - name: Deploy to staging
     if: github.ref == 'refs/heads/develop'
   - name: Deploy to production
     if: github.ref == 'refs/heads/main'
   ```

---

## 📖 リファレンス

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Testing](https://docs.flutter.dev/testing)
- [Firebase CI/CD](https://firebase.google.com/docs/cli#deploy_ci)
- [Cloud Functions Testing](https://firebase.google.com/docs/functions/testing/test-overview)

