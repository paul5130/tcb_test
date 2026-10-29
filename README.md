# 台灣股票每日成交資訊

Flutter 面試實作：輸入民國年月及上市證券代碼，向臺灣證券交易所查詢個股每日成交資訊。使用 Material Design 3 原生元件與 StatefulWidget / setState，無後端、登入或資料庫。

## 環境與安裝

本機驗證環境：Flutter 3.38.3 stable、Dart 3.10.1、macOS arm64。Dart SDK 要求 ^3.10.1。

```sh
flutter pub get
flutter devices
flutter run -d macos
# 或瀏覽器
flutter run -d chrome
# iOS / Android：先開啟模擬器，再 flutter run -d 裝置ID
```

## 專案架構

```text
lib/
  main.dart                    Material 3 App 與主題
  models/stock_day.dart         欄名映射、日期與數值解析、格式化、排序
  services/stock_service.dart   HTTP、逾時、回應與錯誤處理
  pages/stock_page.dart         表單、年月選擇及五種查詢狀態
  widgets/stock_data_table.dart 九欄排序、漲跌顏色、雙向捲動
 test/
  fixtures/stock_day.json       官方實際回應的離線快照
  stock_test.dart               Model 與 Service 單元測試
  widget_test.dart              手機查詢與生命週期測試
```

唯一執行期第三方套件為 `http`；Service 可注入 Client，測試使用 MockClient，不需即時網路。頁面自行建立的 Service 在 dispose 時關閉；外部注入的 Service 由呼叫端管理。

## 功能

- 預設目前年月；民國年／月選擇器，限制民國 99 年至本月，不需選擇日期。
- 4–6 碼英數字證券代碼（保留 ETF 前導零），空白代碼會驗證提示。
- Initial、Loading、Success、Empty、Error 狀態與繁體中文訊息。
- 查詢期間停用條件與按鈕，方法內亦防重複送出；非同步回應檢查 mounted。
- 結果顯示查詢代碼、年月、筆數及官方標題。
- 依最新指定順序列出九欄：日期、成交股數、成交金額、開盤價、最高價、最低價、收盤價、漲跌價差、成交筆數，全部支援首次升冪、再次降冪及方向箭頭。
- 日期按實際日期、數字按數值排序；缺值固定置後，同值依日期排序。
- 價格兩位小數、數量千分位、漲跌正負符號與紅／綠／黑顏色。
- 原生 DataTable 水平與垂直捲動，表單自動換行，桌面最大內容寬度 1500。
- Android INTERNET 與 macOS network.client 權限已加入正式版。

## API 研究（2026-10-29 實測）

官方參考頁：https://www.twse.com.tw/zh/trading/historical/stock-day.html

```text
GET https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY
    ?response=json&date=20261029&stockNo=2330
```

指定日期回傳 `stat: OK`、`date: 20261029`、`total: 18`，含 `title`、`fields`、`data` 等欄位。查詢單位為月；App 將所選年月轉為西元當月 01 日。資料尚未公布或當月交易未結束時，筆數可能變動。

實測欄位順序為：日期、成交股數、成交金額、開盤價、最高價、最低價、收盤價、漲跌價差、成交筆數、註記。App **依 fields 名稱映射**，不假定位置，忽略額外欄位；必要欄位缺失、錯誤日期或不明數值會顯示格式異常。

2026 年 9 月 2330 範例列：

```json
["115/09/01","31,855,287","77,463,413,685","2,395.00","2,440.00","2,390.00","2,440.00","+35.00","65,271",""]
```

- `stockNo=` 空白與 `stockNo=999999` 都回傳 `{"stat":"很抱歉，沒有符合條件的資料!","total":0}`。不支援透過空白查全部股票，也不能由此區分不存在代碼與指定月份無交易，因此使用共同 Empty 說明。
- 未來月份回傳 `{"stat":"查詢日期大於今日，請重新查詢!","total":0}`；其他非 OK 業務狀態呈現官方訊息。
- HTTP 非 200、20 秒逾時、網路失敗與非 JSON／結構異常分別處理。
- 空字串、null、`--` 等缺值顯示 `—`，不當作零；`X0.00` 解析為 0.00，保留 X 原始值於漲跌欄提示。其他無法解讀的符號不任意猜測，回報格式異常。
- 實測 HTTPS 回應含 `access-control-allow-origin: *`，目前可直接由 Web 呼叫；原生 App 不受瀏覽器 CORS 限制。官方可能調整 CORS、流量限制或維護，不能保證永久可用，未加入繞過安全設定的做法。

## 已知限制與可行方案

- 此端點為單一上市證券的月資料，非上櫃資料源；不提供全市場空白代碼模式。
- 若需不指定代碼，可另接官方證券清單做代碼選取；若需全市場單日資料，應另用官方全市場日報端點，而非把空白視為 2330。本題維持明確輸入代碼，未額外增加功能。
- 官方無資料狀態無法區分代碼不存在、未上市、停牌或月份無成交。
- 官方頁面說明資料自民國 99 年 1 月 4 日起提供。
- 測試涵蓋手機 390×844 的版面與查詢流程；實機 iOS／Android 未驗證，不代表已通過各平台商店簽署。
- 本月資料依官方公布進度更新，App 不補值、不推估。

## 測試與建置

```sh
flutter analyze
flutter test
flutter build web
flutter build macos --debug
```

測試涵蓋實際 JSON／欄位重排、民國日期、千分位、缺值、X 值、漲跌正負、八欄數值與日期升降冪、HTTP／JSON／網路／逾時／業務錯誤、空白驗證、手機成功查詢、防重複請求與 dispose 後回應。

驗證結果及平台實際操作紀錄見下方。


## 本機驗證結果

- `flutter analyze`：No issues found。
- `flutter test`：15 項測試全部通過，完全使用離線資料。
- `flutter build web`：成功（包含 Wasm dry run）。Flutter SDK 顯示未使用的 Cupertino 字型提示，不影響輸出。
- `flutter build macos --debug`：成功，輸出 `build/macos/Build/Products/Debug/stock_date_value.app`。
- 瀏覽器實際操作：查詢 2330／115 年 10 月，取得官方 18 筆資料，驗證載入、成功、水平捲動與欄位排序；畫面紀錄為 `docs/web-query.png`。
- macOS 最低部署版本已調整為 12.0，以符合本機 Xcode。
- `flutter build macos` 正式版仍受本機 Flutter 3.38.3／新版 Xcode 的通用架構檢測影響：Flutter 報告 framework 不含 `arm64 x86_64`，但同一日誌的 lipo 顯示兩種架構皆存在。此為工具鏈包裝限制，未修改 SDK 或強制移除 Intel 支援；可先使用 Debug 版，正式版需相容的 Flutter／Xcode 組合再驗證。

## iOS 27 UIScene 遷移

新版 iOS SDK 要求採用 UIScene，原始 Flutter 3.38 範本未設定時會出現 `Application failed to launch: UIScene life cycle is required`。

本專案已依 Flutter 官方遷移指引設定：

- `ios/Runner/Info.plist` 新增 `UIApplicationSceneManifest`，使用 SDK 內建 `FlutterSceneDelegate` 與既有 `Main` storyboard，維持單場景。
- `AppDelegate` 採用 `FlutterImplicitEngineDelegate`，在 `didInitializeImplicitFlutterEngine` 註冊外掛，避免在場景建立前使用舊的註冊時機。
- `pubspec.yaml` 明訂 Flutter >=3.38.0，與所使用的場景 API 相容。

請停止舊的 App 後重新執行 `flutter run -d 裝置ID`；原生啟動設定需要重新編譯，Hot Reload 不會套用。

官方說明：https://docs.flutter.dev/release/breaking-changes/uiscenedelegate

此次驗證：`flutter run -d E4C2AEA4-13D8-426F-8EBD-9AB89C2DF5B3 --debug` 已在 iPhone 18 Pro／iOS 27.0 模擬器完成編譯、啟動與 Dart VM Service 連線，未再出現 UIScene 啟動中止。`flutter build ios --simulator --debug` 的雙架構輸出仍受上述 Flutter／Xcode 架構檢測問題影響；指定單一模擬器執行可通過。
