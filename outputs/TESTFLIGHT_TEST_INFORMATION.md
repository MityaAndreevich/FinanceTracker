# TestFlight — Test Information (copy-paste into ASC)

For **TestFlight → Test Information** + **Beta App Review Information**, needed before submitting the first External build for Beta App Review. Positioning: private, on-device, manual — no banned claims (no "encrypted", "AI-powered", "best", "#1", "free forever"). English is what the reviewer reads; RU optional if you localize.

---

## 1. Beta App Description  (field: "Beta App Description")

**EN (primary):**
```
Budget Crab is a private, on-device money tracker. Add an expense in seconds — type it or say it out loud — and it stays on your iPhone. No account, no sign-up, no bank connection. Log income and expenses, organize with a two-tier category system, see where your money goes with clear monthly summaries and a "safe to spend" view, and export your data to CSV, PDF, or spreadsheet. No ads. Cancel anytime.

We'd love feedback on how fast and reliable logging feels, the voice entry, and the overall clarity of the app.
```

**RU (optional):**
```
Budget Crab — приватный трекер денег, всё на устройстве. Добавьте трату за секунды: введите или продиктуйте — данные остаются на вашем iPhone. Без аккаунта, без регистрации, без подключения к банку. Доходы и расходы, двухуровневые категории, понятные месячные итоги и «сколько можно потратить», экспорт в CSV, PDF или таблицу. Без рекламы. Отмена в любой момент.

Будем рады отзывам о скорости и надёжности ввода, голосовом вводе и общей понятности.
```

---

## 2. What to Test  (field: "What to Test" — per build note to testers)

**EN:**
```
Please try:
1. Add a few transactions by typing (income and expense).
2. Add a transaction using voice (tap the mic and say an amount + what it was).
3. Add spending from Siri / the Shortcuts app ("Add Transaction" shortcut).
4. Assign and rename categories; try "recategorize" and the two-tier structure.
5. Open the monthly summary / "safe to spend" and the analytics breakdown.
6. Export the current month to CSV, PDF, and spreadsheet.
7. Open Premium and start the Yearly 7-day free trial, and try Lifetime (sandbox — no real charge). Confirm the trial and prices read correctly.
8. Turn on Face ID lock in Settings and re-open the app.
9. If you use another language (RU / ES / PT-BR / UK), switch your device language and check the app + voice entry.

Tell us anything that feels slow, confusing, or wrong.
```

**RU:**
```
Пожалуйста, проверьте:
1. Добавьте несколько операций вручную (доход и расход).
2. Добавьте операцию голосом (микрофон → сумма + на что).
3. Добавьте трату из Siri / приложения «Команды» (ярлык «Add Transaction»).
4. Назначайте и переименовывайте категории; попробуйте «сменить категорию» и двухуровневую структуру.
5. Откройте месячный итог / «сколько можно потратить» и аналитику.
6. Экспортируйте текущий месяц в CSV, PDF и таблицу.
7. Откройте Premium, запустите годовой 7-дневный триал и попробуйте Lifetime (sandbox — без реальных списаний). Проверьте, что триал и цены отображаются верно.
8. Включите вход по Face ID в Настройках и переоткройте приложение.
9. Если пользуетесь другим языком (RU / ES / PT-BR / UK) — переключите язык устройства и проверьте приложение + голосовой ввод.

Напишите обо всём, что кажется медленным, непонятным или неверным.
```

---

## 3. Feedback Email  (field: "Feedback Email")
```
Dmitry.logachev.usa@icloud.com
```
🟡 Recommendation: if you have (or can make) a dedicated support address (e.g. support@yourdomain), use that instead — testers and later App Store "Support URL" reuse it, and you may not want your personal iCloud public. Personal email is fine for the beta.

---

## 4. Beta App Review Information  (reviewer-facing — reduces rejection risk)

**Sign-in required:** No (leave demo account fields empty).

**Notes for Review (field: "Notes"):**
```
Budget Crab is an offline personal expense tracker. No account or login is required — open the app and use it immediately. There are no bank connections, no money movement, and no trading or investing; all data is entered manually by the user and stored on-device. Speech input is transcribed on-device. Siri/Shortcuts actions are provided via App Shortcuts.

In-app purchases (Premium Monthly, Yearly, Lifetime) unlock advanced features (all-time exports, CSV import, custom fields, advanced filters). The Yearly plan includes a 7-day free trial. IAPs can be validated in the sandbox — no real charge. No demo account is needed.
```

**Contact Information:** your first/last name, email, and phone (required fields — fill with your own).

---

## 5. Also required before External review (quick checklist)
- [ ] **Privacy Policy URL** — ASC requires one. If not set yet, this must be added (App Information → Privacy Policy URL). Flag if you don't have a hosted policy — we have a template in `.studios/AppStudio/templates/privacy-policy-template.html`.
- [ ] **Export Compliance** — already handled (ITSAppUsesNonExemptEncryption = NO).
- [ ] Attach build **1.0 (2)** to the External group, then **Submit for Beta App Review** (~24h for first external build).
- [ ] Turn on **Public Link** in the group → share with your friend.
