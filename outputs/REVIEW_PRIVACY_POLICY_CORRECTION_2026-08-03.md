# Privacy Policy correction — proposed diff for review

**Status: NOT APPLIED. NOT PUBLISHED.** `docs/PRIVACY_POLICY.md` is untouched on
disk. This file is the proposal. The full proposed text is reproduced at the end
so it can be read as prose rather than as a patch.

Date: 2026-08-03 · Prepared for founder review · Legal document — founder decides
what goes live.

---

## 1. The encryption claim — verified before rewording

The brief said not to take anyone's word for this, so it was checked.

**`notebooklm de492776` does not cover it.** Asked directly, the notebook
answered: *"there is no specific information regarding the encryption levels of
CloudKit private databases (Standard vs. Advanced Data Protection)"* and offered
to go searching. Per `CLAUDE.md`, a notebook miss means fall back to primary
sources, not to memory. Two Apple Platform Security pages settle it.

**Citation 1 — who holds the keys under standard protection.**
Apple Platform Security, *iCloud encryption*
(https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web):

> "For other services, such as Photos and iCloud Drive, the service keys are
> stored in iCloud Hardware Security Modules in Apple data centers, and can be
> accessed by some Apple services."

**Citation 2 — and this one is the part the brief did not anticipate.**
Apple Platform Security, *Advanced Data Protection for iCloud*:

> "Advanced Data Protection also automatically protects CloudKit fields that
> third-party developers choose to mark as encrypted, and all CloudKit assets."

### What this means, stated precisely

The brief's diagnosis was right and **understated by one condition**. End-to-end
encryption of Budget Crab's synced data is not gated on one user choice. It is
gated on two things, and only one of them belongs to the user:

1. **The user has enabled Advanced Data Protection.** Their choice, off by
   default, not assertable on their behalf. This is the condition the brief
   identified.
2. **We have marked the fields as encrypted in the CloudKit schema.** *Ours.*
   Per citation 2, ADP protects third-party fields that the developer *chooses
   to mark* as encrypted. A field we do not mark is not end-to-end encrypted
   even for a user who has ADP switched on.

`outputs/DESIGN_ICLOUD_SYNC_1_0_4.md` contains **zero** occurrences of
`encryptedValues`, `allowsCloudEncryption`, or any encryption-marking decision
(grepped). So as the 1.0.4 design currently stands, condition 2 is unmet, and
**no encryption claim of any strength would be true for any user** — including
the ADP users the current sentence implicitly relies on.

This is why the proposal deletes the claim outright rather than softening it to
"end-to-end encrypted if you have Advanced Data Protection enabled." That
softened sentence, which is the obvious rewrite and the one I would have written
without citation 2, would **also be false** until we mark the fields. The
instruction was to write the claim the citation supports. The citation currently
supports no affirmative encryption claim about synced data, so the proposal
makes none.

### A consequence outside the policy

`DESIGN_ICLOUD_SYNC_1_0_4.md` §2.2 specifies that the sync consent screen will
tell users:

> "Where it goes: your own private iCloud. **We have no servers and cannot read
> it.** It counts against your iCloud storage."

First half true. Second half has the same defect as the sentence being removed
here — worse, in fact, because a consent screen is where the user makes the
decision. This was not in the brief's scope and is **not** changed by this
proposal, but it must be fixed before that screen is built, and the proposal
records the dependency in the file so the two documents are written together.

---

## 2. What changed, and why — in the brief's priority order

### (a) The encryption claim — REMOVED, in both places

- **Line 37** (§2): the sentence *"This data is end-to-end encrypted by Apple;
  neither Apple nor we can read its contents."*
- **Line 131** (§9): *"data in transit and at rest in iCloud is encrypted by
  Apple using end-to-end encryption. Only your devices logged into the same
  Apple ID can decrypt it."*

Both removed with their surrounding sync paragraphs (see (c)). Rationale above.
This was the right thing to flag as the dangerous one: (b) and (c) describe
features that merely don't exist yet, which is an accuracy problem. (a) is an
affirmative security guarantee about financial data, made to users who may be
choosing this app *because of* that guarantee, and it would have remained false
after sync shipped.

§9 gains a replacement paragraph that is true today: a note that iCloud/computer
**backups** are governed by Apple's terms, not ours. Worth having independently
— the policy previously implied device-level protection covered everything, and
a user who backs up to iCloud is in a materially different position.

### (b) Camera / Receipt OCR — REMOVED (line 54, and the Vision bullet at 144)

Verified independently, not taken on trust:

- `NSCameraUsageDescription`: **zero** matches anywhere in the project. The only
  hits in the repo are in `outputs/` planning documents.
- `import Vision`: **zero** matches. `VNRecognizeText`, `UIImagePickerController`,
  `PHPicker`, `AVCaptureDevice`: **zero** matches.

Concur with the brief's reasoning: a policy describing camera access that the
Info.plist does not declare is a self-inflicted inconsistency of exactly the kind
reviewers check, and it also pre-commits the product to the feature that
`DECISION_RECEIPT_INPUT_PRETEST.md` exists to gate. Re-add when it ships.

**The inverse defect, which nobody had flagged.** While verifying, the reverse
turned up: the App **does** declare `NSMicrophoneUsageDescription` and
`NSSpeechRecognitionUsageDescription` (both in `project.pbxproj`), and imports
`Speech` and `AVFoundation` — and the published policy **never mentions the
microphone at all**. That is the same category of inconsistency pointing the
other way, and arguably the worse one: an undisclosed permission is a harder
question to answer than a disclosed non-permission. The proposal adds an honest
paragraph covering voice entry, and corrects the §10 framework list to the
frameworks actually linked.

### (c) iCloud sync as an available Premium feature — REMOVED (lines 12, 37, 131, 142)

Also verified: `CloudKit` is not imported anywhere in the app.
`SharedModelContainer.swift:43` states in a comment that CloudKit stays `.none`
in 1.0.3. So the feature is not merely unshipped, it is unlinked.

§2 gains one plain sentence in its place — *"The App does not sync your data to
iCloud or anywhere else"* — because silence would be ambiguous, and a
finance-app user reasonably wants that stated rather than inferred. §6
(international transfers) is simplified for the same reason.

**The 1.0.4 dependency is recorded in the file**, as asked, as a markdown comment
at the top. Markdown comments do not render, so it travels with the document
without appearing on the published page. It names
`DESIGN_ICLOUD_SYNC_1_0_4.md` §2.2, requires the two to be written in the same
change, and carries both citations plus the §2.2 defect above — so whoever
restores this text has the reasoning in front of them and does not re-derive it
or paste back the old sentence.

### (d) "Vela" → "Budget Crab", and the effective date

`INFOPLIST_KEY_CFBundleDisplayName = "Budget Crab"` in `project.pbxproj` (both
configurations); the name is "Budget Crab" across all five `.lproj` bundles.
"Vela" is a former name — `ff77d5b` renamed *to* Vela, and the product was
renamed again afterwards, leaving this document behind.

Renamed in all seven user-facing occurrences. **"Vela" is deliberately left alone
in code**: it survives only as the on-disk store filename (`Vela.sqlite`), which
`SharedModelContainer.swift:64` documents as intentionally frozen. Renaming that
would be a migration, not a rename.

Dates changed from *"Last updated: June 22, 2026 / Effective date: Upon
publication of Vela version 1.0"* to a concrete **August 3, 2026** for both, plus
a visible one-line note stating what the prior version got wrong. Rationale: the
old effective date is tied to a version and a product name that no longer exist,
so it cannot be left as-is; and a silent correction to a published legal document
is worse than a disclosed one. A user who read the June version was told
something false about encryption, and the document should say so rather than
quietly no longer say it. If you would rather not draw attention to it, the
supersession line is the one paragraph here that is purely a judgment call and
can be cut without affecting correctness.

### The rule itself — WRITTEN INTO §11

Added as the opening of §11, per the brief:

> **This policy describes what the App does, never what is planned.** A feature
> is described here only once it is shipping in a version available on the App
> Store, and a feature that is removed is removed from this document in the same
> release. We would rather this document be dull and correct than complete in
> advance.

A new short section, **"What this policy covers"**, states the same rule near the
top in user-facing language.

`outputs/ASO_COPY_PACK.md:5` already states the rule for store copy, and it turns
out to say something sharper than the brief credited it with:

> **Honesty guardrail:** advertise only shipped features. Receipt scan / AI entry
> = HELD until v1.1 […] No banned claims (no "best/#1/free forever/**encrypted**/
> AI-powered").

Two things follow. First, that document had **already** held receipt scan back
from store copy for being unshipped — while the privacy policy was describing it
as a live feature. The rule was in force; the policy was the one surface it was
never applied to, which is precisely the brief's point about where breaking it
costs most. Second, "encrypted" is on that file's **banned-claims list** for
marketing copy. So the strongest encryption claim in the entire project was being
made in the legal document, and the same claim was already prohibited in the
advertising. That inversion is worth keeping in view.

---

## 3. What was NOT changed, deliberately

- **The "Data Not Collected" summary table.** Unaffected by all four corrections;
  none of them changes a collection answer.
- **§§3, 4, 5, 7, 8, 12, 13.** No defects found.
- **The "Tell me what's missing" disclosure** (added in `8b5e8d0`). Checked
  against the removals; still accurate, including the "Split purchases" example.
- **`_web-files-for-upload/`.** Gitignored, not touched. Publishing is yours.

---

## 4. The diff

Applies to `docs/PRIVACY_POLICY.md` at `c87f1f5`. 13 lines removed, 51 added
(most of the addition is the non-rendering internal comment block).

```diff
--- a/docs/PRIVACY_POLICY.md	2026-08-02 23:10:27
+++ docs/PRIVACY_POLICY.md (PROPOSED)	2026-08-03 18:59:28
@@ -1,23 +1,69 @@
 # Privacy Policy
 
-**Last updated:** June 22, 2026
-**Effective date:** Upon publication of Vela version 1.0 on the App Store
+**Last updated:** August 3, 2026
+**Effective date:** August 3, 2026
 
+This revision supersedes the version dated June 22, 2026. That version described three things the App does not do — camera / receipt scanning, iCloud sync, and end-to-end encryption of synced data — and used a former product name. See "What this policy covers", below.
+
+<!--
+INTERNAL NOTE — markdown comment, not rendered to users.
+
+Scope rule (see §11): this document describes only what the shipped App does.
+
+DEPENDENCY — iCloud sync, planned for 1.0.4. When sync ships, the paragraphs
+removed in the 2026-08-03 revision come back, and their wording MUST be written
+together with the sync consent screen specified in
+`outputs/DESIGN_ICLOUD_SYNC_1_0_4.md` §2.2, in the same change. Do not restore
+the old wording.
+
+Two things the old wording got wrong, which must not be reintroduced:
+
+1. "End-to-end encrypted by Apple; neither Apple nor we can read its contents"
+   is FALSE for a third-party CloudKit private database under Standard Data
+   Protection. Apple Platform Security, "iCloud encryption": "For other
+   services, such as Photos and iCloud Drive, the service keys are stored in
+   iCloud Hardware Security Modules in Apple data centers, and can be accessed
+   by some Apple services."
+   https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web
+
+2. End-to-end encryption of OUR data requires BOTH conditions, not one:
+   (a) the user has turned on Advanced Data Protection, which is their choice
+       and cannot be asserted on their behalf; AND
+   (b) we mark the fields encrypted in the CloudKit schema. Apple Platform
+       Security, "Advanced Data Protection for iCloud": "Advanced Data
+       Protection also automatically protects CloudKit fields that third-party
+       developers choose to mark as encrypted, and all CloudKit assets."
+   Condition (b) is ours to satisfy and is absent from the 1.0.4 design as
+   written. If (b) is not implemented, an ADP user gets no end-to-end
+   encryption of these fields either, and no encryption claim may be made.
+
+Also inconsistent with the old sync wording: DESIGN_ICLOUD_SYNC_1_0_4.md §2.2
+currently proposes telling users "We have no servers and cannot read it." The
+first half is true. The second half has the same defect as the claim removed
+here, and must be fixed in that document before it reaches a screen.
+-->
+
 ---
 
 ## In plain language
 
-Vela keeps all of your financial data on your device. We have no servers, no cloud database, and no third-party data partners. We do not see, store, or sell your transactions, account names, or any other information you enter.
+Budget Crab keeps all of your financial data on your device. We have no servers, no cloud database, and no third-party data partners. We do not see, store, or sell your transactions, account names, or any other information you enter.
 
-The only network traffic the app generates is to Apple, exclusively for processing in-app purchases through StoreKit and (if you choose to enable it) syncing your data between your own Apple devices via iCloud. We never receive any of that data.
+The only network traffic the app generates is to Apple, exclusively for processing in-app purchases through StoreKit. We never receive any of that data.
 
 If that is enough for you, you can stop reading here. The rest of this document is the formal disclosure required by privacy laws.
 
 ---
 
+## What this policy covers
+
+This policy describes the App as it ships today. It does not describe planned or future features. If a feature is not in the version of the App you have installed, it is not in this document — and when such a feature ships, this document is updated in the same release.
+
+---
+
 ## 1. Who we are
 
-This Privacy Policy describes how Dmitry Logachev (the "Developer", "we", "our", "us") handles personal information in connection with the Vela iOS application (the "App").
+This Privacy Policy describes how Dmitry Logachev (the "Developer", "we", "our", "us") handles personal information in connection with the Budget Crab iOS application (the "App").
 
 **Contact:**
 Email: Dmitry.logachev.usa@icloud.com
@@ -28,13 +74,13 @@
 
 **We do not collect any personal information from you.**
 
-All data you enter into Vela — including but not limited to transaction amounts, dates, merchants, notes, account names, category names, and currency preferences — is stored exclusively on your device and remains under your sole control. None of this information is transmitted to us, our servers (we have none), or any third party.
+All data you enter into Budget Crab — including but not limited to transaction amounts, dates, merchants, notes, account names, category names, and currency preferences — is stored exclusively on your device and remains under your sole control. None of this information is transmitted to us, our servers (we have none), or any third party.
 
 ### Information processed by Apple, not by us
 
 When you make an in-app purchase, Apple processes the transaction through its StoreKit service. Apple may collect information about your purchase as described in [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). We do not receive your name, payment details, or any other personally identifying information from Apple; we only receive an anonymized cryptographic receipt confirming that a valid purchase was made.
 
-If you enable iCloud sync (available as a Premium feature), Apple synchronizes your data between your own Apple devices using your private iCloud account. This data is end-to-end encrypted by Apple; neither Apple nor we can read its contents. You can disable iCloud sync at any time in Settings, after which synchronization stops and no data remains in iCloud.
+The App does not sync your data to iCloud or anywhere else. Your ledger exists on the device you entered it on, and nowhere else, unless you export it yourself.
 
 ### Information you choose to send us
 
@@ -51,15 +97,17 @@
 
 When you grant the App permission to use Face ID, Touch ID, or your device passcode, your biometric template never leaves the Secure Enclave on your device. We never see, store, or transmit it.
 
-If you grant the App permission to access the camera (for the optional Receipt OCR feature), photos are processed by Apple's on-device Vision framework. No image is uploaded to any server, including ours. After text extraction, the photo is discarded unless you explicitly choose to attach it to a transaction.
+If you use voice entry, the App records audio only while you hold the microphone button, and transcribes it using Apple's on-device speech recognition on your iPhone. The audio is not uploaded, is not stored as a file, and is discarded once the text has been produced. If your iPhone does not have on-device dictation installed for your language, the microphone button does not appear.
 
+The App does not request access to your camera or your photo library, and does not read images.
+
 ---
 
 ## 3. How we use your information
 
 Because we do not collect any personal information, we do not use it for any purpose.
 
-The information you enter into Vela is used by the App, on your device, to provide the functionality you have requested: displaying your dashboard, generating analytics charts, exporting reports, and producing optional smart insights based on your usage patterns. All of this processing happens locally on your device.
+The information you enter into Budget Crab is used by the App, on your device, to provide the functionality you have requested: displaying your dashboard, generating analytics charts, exporting reports, and producing optional smart insights based on your usage patterns. All of this processing happens locally on your device.
 
 ---
 
@@ -77,13 +125,13 @@
 
 ## 6. International data transfers
 
-We do not transfer your information internationally because we do not receive it in the first place. Any synchronization between your own devices through iCloud is handled by Apple and is subject to Apple's geographical infrastructure and policies.
+We do not transfer your information internationally, because we do not receive it in the first place. Your data does not leave your device.
 
 ---
 
 ## 7. Data retention
 
-All data you enter into Vela remains on your device until you choose to delete it. You can:
+All data you enter into Budget Crab remains on your device until you choose to delete it. You can:
 
 - Delete individual transactions, categories, or accounts from within the App at any time.
 - Use **Settings → General → Reset Transactions** to remove all transactions while keeping your categories and accounts.
@@ -128,9 +176,9 @@
 
 These protections rely on your device having a passcode set. We strongly encourage you to use a strong passcode and to enable biometric authentication on your device.
 
-If you enable iCloud sync, data in transit and at rest in iCloud is encrypted by Apple using end-to-end encryption. Only your devices logged into the same Apple ID can decrypt it.
+If you use iCloud Backup or back your device up to a computer, that backup is made and protected by Apple or by your computer, under their terms rather than ours. The protections described above apply to the App's data on your device; they do not govern backups you have chosen to make.
 
-No security measure is perfect. While we have designed Vela to be one of the most privacy-respecting finance applications on the App Store, you should always practice good operational security on your device, including keeping iOS up to date and using a unique device passcode.
+No security measure is perfect. While we have designed Budget Crab to be one of the most privacy-respecting finance applications on the App Store, you should always practice good operational security on your device, including keeping iOS up to date and using a unique device passcode.
 
 ---
 
@@ -139,9 +187,8 @@
 The App uses the following first-party Apple services only:
 
 - **StoreKit** — for in-app purchases
-- **CloudKit** — for optional iCloud sync (Premium feature)
 - **LocalAuthentication** — for biometric / passcode unlock
-- **Vision** — for on-device receipt OCR (Premium feature)
+- **Speech and AVFoundation** — for optional on-device voice entry
 
 We do not use any third-party SDKs, analytics tools, advertising networks, crash reporters, or telemetry services.
 
@@ -149,6 +196,8 @@
 
 ## 11. Changes to this Privacy Policy
 
+**This policy describes what the App does, never what is planned.** A feature is described here only once it is shipping in a version available on the App Store, and a feature that is removed is removed from this document in the same release. We would rather this document be dull and correct than complete in advance.
+
 We may update this Privacy Policy from time to time, for example to reflect new features, address regulatory changes, or correct mistakes. When we do, we will update the "Last updated" date at the top of this document. Material changes will be communicated through the App. Your continued use of the App after a change becomes effective constitutes acceptance of the revised Privacy Policy.
 
 You can always find the current version of this Privacy Policy at the URL printed on the App's paywall and About screens.
```

---

## 5. Full proposed text (for reading as prose)

<!-- The rendered document begins below. -->

# Privacy Policy

**Last updated:** August 3, 2026
**Effective date:** August 3, 2026

This revision supersedes the version dated June 22, 2026. That version described three things the App does not do — camera / receipt scanning, iCloud sync, and end-to-end encryption of synced data — and used a former product name. See "What this policy covers", below.

<!--
INTERNAL NOTE — markdown comment, not rendered to users.

Scope rule (see §11): this document describes only what the shipped App does.

DEPENDENCY — iCloud sync, planned for 1.0.4. When sync ships, the paragraphs
removed in the 2026-08-03 revision come back, and their wording MUST be written
together with the sync consent screen specified in
`outputs/DESIGN_ICLOUD_SYNC_1_0_4.md` §2.2, in the same change. Do not restore
the old wording.

Two things the old wording got wrong, which must not be reintroduced:

1. "End-to-end encrypted by Apple; neither Apple nor we can read its contents"
   is FALSE for a third-party CloudKit private database under Standard Data
   Protection. Apple Platform Security, "iCloud encryption": "For other
   services, such as Photos and iCloud Drive, the service keys are stored in
   iCloud Hardware Security Modules in Apple data centers, and can be accessed
   by some Apple services."
   https://support.apple.com/guide/security/icloud-encryption-sec3cac31735/web

2. End-to-end encryption of OUR data requires BOTH conditions, not one:
   (a) the user has turned on Advanced Data Protection, which is their choice
       and cannot be asserted on their behalf; AND
   (b) we mark the fields encrypted in the CloudKit schema. Apple Platform
       Security, "Advanced Data Protection for iCloud": "Advanced Data
       Protection also automatically protects CloudKit fields that third-party
       developers choose to mark as encrypted, and all CloudKit assets."
   Condition (b) is ours to satisfy and is absent from the 1.0.4 design as
   written. If (b) is not implemented, an ADP user gets no end-to-end
   encryption of these fields either, and no encryption claim may be made.

Also inconsistent with the old sync wording: DESIGN_ICLOUD_SYNC_1_0_4.md §2.2
currently proposes telling users "We have no servers and cannot read it." The
first half is true. The second half has the same defect as the claim removed
here, and must be fixed in that document before it reaches a screen.
-->

---

## In plain language

Budget Crab keeps all of your financial data on your device. We have no servers, no cloud database, and no third-party data partners. We do not see, store, or sell your transactions, account names, or any other information you enter.

The only network traffic the app generates is to Apple, exclusively for processing in-app purchases through StoreKit. We never receive any of that data.

If that is enough for you, you can stop reading here. The rest of this document is the formal disclosure required by privacy laws.

---

## What this policy covers

This policy describes the App as it ships today. It does not describe planned or future features. If a feature is not in the version of the App you have installed, it is not in this document — and when such a feature ships, this document is updated in the same release.

---

## 1. Who we are

This Privacy Policy describes how Dmitry Logachev (the "Developer", "we", "our", "us") handles personal information in connection with the Budget Crab iOS application (the "App").

**Contact:**
Email: Dmitry.logachev.usa@icloud.com

---

## 2. Information we collect

**We do not collect any personal information from you.**

All data you enter into Budget Crab — including but not limited to transaction amounts, dates, merchants, notes, account names, category names, and currency preferences — is stored exclusively on your device and remains under your sole control. None of this information is transmitted to us, our servers (we have none), or any third party.

### Information processed by Apple, not by us

When you make an in-app purchase, Apple processes the transaction through its StoreKit service. Apple may collect information about your purchase as described in [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). We do not receive your name, payment details, or any other personally identifying information from Apple; we only receive an anonymized cryptographic receipt confirming that a valid purchase was made.

The App does not sync your data to iCloud or anywhere else. Your ledger exists on the device you entered it on, and nowhere else, unless you export it yourself.

### Information you choose to send us

The App contains no analytics and no telemetry. It does contain a "Tell me what's missing" screen, which opens a draft message in your own Mail app, addressed to our support address. Two things travel in that draft:

- a subject line carrying the App version, your App language, and your device model (for example, "iPhone14,5"), so that support mail can be sorted; and
- **only if you leave the toggle on** — a short usage summary describing which features you have used, in ranges rather than exact numbers (for example, "Transactions: 51–200", "Split purchases: yes · 1–5").

That summary never contains anything from your ledger: no amounts, no merchants, no category names, no dates, and no account names. It is shown to you in full, on screen, before Mail opens, and a clearly labelled toggle removes it entirely. **The App itself transmits nothing.** Your Mail app sends the message, from your own mail account, when you press Send — and you can edit or delete any part of the draft first. If you cancel, nothing leaves your device.

Once you do send us an email, we have it, in the same way that anyone has an email you send them. We read it, we may reply to it, and we delete support correspondence when it is no longer needed.

### Information processed automatically by your device

When you grant the App permission to use Face ID, Touch ID, or your device passcode, your biometric template never leaves the Secure Enclave on your device. We never see, store, or transmit it.

If you use voice entry, the App records audio only while you hold the microphone button, and transcribes it using Apple's on-device speech recognition on your iPhone. The audio is not uploaded, is not stored as a file, and is discarded once the text has been produced. If your iPhone does not have on-device dictation installed for your language, the microphone button does not appear.

The App does not request access to your camera or your photo library, and does not read images.

---

## 3. How we use your information

Because we do not collect any personal information, we do not use it for any purpose.

The information you enter into Budget Crab is used by the App, on your device, to provide the functionality you have requested: displaying your dashboard, generating analytics charts, exporting reports, and producing optional smart insights based on your usage patterns. All of this processing happens locally on your device.

---

## 4. Information sharing and disclosure

We do not share, sell, rent, lease, or otherwise disclose any user information to any third party, including advertisers, data brokers, analytics providers, or affiliates. We do not have any third parties with whom to share information, because we do not collect information.

---

## 5. Children's privacy

The App is not directed at children under the age of 13 (or under 16 in the European Economic Area). We do not knowingly collect information from anyone, including children. Because no information is collected from anyone, no information is collected from children.

---

## 6. International data transfers

We do not transfer your information internationally, because we do not receive it in the first place. Your data does not leave your device.

---

## 7. Data retention

All data you enter into Budget Crab remains on your device until you choose to delete it. You can:

- Delete individual transactions, categories, or accounts from within the App at any time.
- Use **Settings → General → Reset Transactions** to remove all transactions while keeping your categories and accounts.
- Uninstall the App from your device. This deletes the local database and all associated files immediately.

We do not retain any data on our side, because none is ever transmitted to us.

---

## 8. Your privacy rights

Depending on where you live, you may have rights under data protection laws such as the European Union's General Data Protection Regulation (GDPR), the United Kingdom GDPR, the California Consumer Privacy Act (CCPA), or other regional laws. These rights typically include the right to access, correct, delete, or port your personal information, as well as the right to object to certain processing.

Because we do not hold any of your personal information, the way to exercise these rights is directly through the App on your device:

- **Right of access:** Use **Settings → Data → Export** to export your full data history as CSV, TSV, or PDF.
- **Right to rectification:** Edit any transaction or category directly within the App.
- **Right to erasure:** Delete individual records, reset all transactions via Settings, or uninstall the App.
- **Right to data portability:** Export your data as CSV, which is a standard, machine-readable format.
- **Right to object / restrict processing:** Stop using the App; uninstall it.

You do not need to contact us to exercise any of these rights, because we do not control your data — you do. If you have questions about how the App works in relation to these rights, you may contact us at the email address listed in Section 1.

### Do Not Track

We honor "Do Not Track" signals because we do not track anyone under any circumstances.

### App Tracking Transparency (ATT)

We do not request the ATT permission because we do not engage in tracking.

---

## 9. Security

We use Apple's standard iOS security mechanisms to protect data on your device, including:

- File-level encryption via `NSFileProtectionComplete`, which encrypts the App's database using a key derived from your device passcode.
- Optional biometric authentication (Face ID / Touch ID) required to open the App, which you can enable in Settings.
- Marking sensitive Keychain entries as accessible only when a device passcode is set and never synchronized to backups.
- Protection of in-app screens against accidental exposure in the multitasking switcher.

These protections rely on your device having a passcode set. We strongly encourage you to use a strong passcode and to enable biometric authentication on your device.

If you use iCloud Backup or back your device up to a computer, that backup is made and protected by Apple or by your computer, under their terms rather than ours. The protections described above apply to the App's data on your device; they do not govern backups you have chosen to make.

No security measure is perfect. While we have designed Budget Crab to be one of the most privacy-respecting finance applications on the App Store, you should always practice good operational security on your device, including keeping iOS up to date and using a unique device passcode.

---

## 10. Third-party services

The App uses the following first-party Apple services only:

- **StoreKit** — for in-app purchases
- **LocalAuthentication** — for biometric / passcode unlock
- **Speech and AVFoundation** — for optional on-device voice entry

We do not use any third-party SDKs, analytics tools, advertising networks, crash reporters, or telemetry services.

---

## 11. Changes to this Privacy Policy

**This policy describes what the App does, never what is planned.** A feature is described here only once it is shipping in a version available on the App Store, and a feature that is removed is removed from this document in the same release. We would rather this document be dull and correct than complete in advance.

We may update this Privacy Policy from time to time, for example to reflect new features, address regulatory changes, or correct mistakes. When we do, we will update the "Last updated" date at the top of this document. Material changes will be communicated through the App. Your continued use of the App after a change becomes effective constitutes acceptance of the revised Privacy Policy.

You can always find the current version of this Privacy Policy at the URL printed on the App's paywall and About screens.

---

## 12. Governing law

This Privacy Policy is governed by the laws applicable to the Developer's place of residence. Nothing in this Privacy Policy limits the rights you may have under mandatory consumer-protection or data-protection laws applicable to you.

---

## 13. Contact us

If you have any questions or concerns about this Privacy Policy or the App's privacy practices, you can reach us at:

**Email:** Dmitry.logachev.usa@icloud.com

We aim to respond to all privacy-related inquiries within 14 days.

---

## Summary table (for the App Store privacy nutrition label)

| Data Category | Collected by Us | Linked to You | Used for Tracking |
|---|---|---|---|
| Purchase History (via Apple's StoreKit) | No (Apple processes it) | No | No |
| Financial Info (transactions you enter) | No | No | No |
| Identifiers | No | No | No |
| Usage Data | No | No | No |
| Diagnostics | No | No | No |
| Contacts, Photos, Location | No | No | No |

This corresponds to App Store Connect's "Data Not Collected" privacy label.

---

*This Privacy Policy is published in good faith to inform users of how the App treats personal information. It is not legal advice. Users with specific legal questions should consult an attorney.*
