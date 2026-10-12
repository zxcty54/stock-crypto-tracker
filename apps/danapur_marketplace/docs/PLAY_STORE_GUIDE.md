# Google Play Store Review & Release Guide

Is guide mein Google Play Console ke policies, review checklist, aur declarations ke exact answers diye gaye hain taaki app review mein na fase.

---

## 1. Release files: Testing APK vs Play Store AAB

Abhi workflow **sirf universal APK** (`danapur-bazaar.zip`) generate aur deliver karta hai:
- **`danapur-bazaar.zip` ke andar `danapur-bazaar.apk`**: Apne ya kisi bhi Android phone mein direct install aur testing ke liye.
- **Signing**: By default Android debug key se signed rehta hai taaki bina kisi base64 keystore setup ke directly install ho sake. Kisi secret ya base64 key ki abhi zaroorat nahi hai.

### Future Play Store Release (Jab publish karna ho)

Google Play Console production launch ke liye `.aab` (Android App Bundle) aur dedicated signing key mangta hai:
1. `keytool` se upload keystore banayein:
   ```bash
   keytool -genkey -v -keystore danapur-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias danapur -storetype JKS
   ```
2. Keystore ko base64 encode karein:
   ```bash
   base64 -w 0 danapur-upload.jks > keystore_base64.txt
   ```
3. GitHub Repository **Settings → Secrets and variables → Actions** mein 4 secrets add karein:
   - `DANAPUR_ANDROID_KEYSTORE_BASE64` (file ka content)
   - `DANAPUR_KEYSTORE_PASSWORD`
   - `DANAPUR_KEY_ALIAS` (e.g. `danapur`)
   - `DANAPUR_KEY_PASSWORD`
4. CI workflow mein `flutter build appbundle` enable karein.

---

## 2. Play Console: Policy Declarations

Google Play Console ke **App content** section mein ye forms fill karne hote hain:

### A. App Access (Reviewer Login)
Google reviewers app test karte hain. Agar login lock hoga toh reject ho jayega.
- **Option select karein**: *"All or some functionality is restricted"*
- **Instructions for reviewer**:
  > "Users can browse Danapur shops, products, categories, and mandi rates without logging in. To test authenticated features (placing a cash order, managing a shop, or personal expenses), reviewers can use the following test account:
  > • Email: `playstore-reviewer@danapurbazaar.in` (ya apna verified test account)
  > • Password: `<your-test-password>`
  > Or sign up with any email (confirmation email will be sent). All orders are physical cash-on-delivery; no digital payments exist in the app."

### B. Data Safety Form (Exact Answers)
Google Play policy ke mutabiq app jo data leta hai use accurately declare karna zaroori hai:

| Data Type | Collected? | Shared with 3rd parties? | Purpose | Ephemeral? |
|---|---|---|---|---|
| **Precise Location** | Yes | No | App functionality (verify 500m delivery radius for cash orders) | Yes (accessed only in foreground when user taps "Use current location") |
| **Name** | Yes | No | Order delivery coordination (shared only with fulfilling seller) | No |
| **Email address** | Yes | No | Account authentication & security | No |
| **Phone number** | Yes | No | Order communication & cash delivery | No |
| **Physical address** | Yes | No | Physical order delivery (shared only with fulfilling seller) | No |
| **Photos** | Yes | No | Optional storefront verification photo uploaded by shop owners to private storage | No |
| **Financial info** | **NO** | No | App handles NO credit cards, debit cards, bank details, or UPI info. All orders are cash on delivery. | N/A |

- **Security Practices**:
  - Data encrypted in transit? **Yes** (HTTPS/TLS)
  - Can users request data deletion? **Yes**

### C. Account Deletion Requirement
Google Play policy requires in-app deletion and a public web deletion link:
- **In-App deletion**: Har user ke liye available hai:
  `Top menu (⋮) → My account & privacy → Delete account & data`
- **Web deletion link** (Play Console field):
  `https://<your-domain>/#/account` ya aapka privacy page jahan account deletion request email di gayi ho.

### D. User Generated Content (UGC) Policy
Marketplace mein shops, products aur order reviews user content hain. Google Play review ke requirements:
- **Acceptable Use Policy**: In-app Info (`About → Privacy & Terms`) mein hate speech, harassment, fake listings, adult content, aur illegal goods strictly prohibited hain.
- **In-App Reporting**:
  - Har shop page par: **Report shop** button
  - Har product page par: **Report objectionable listing** button
  - Har review card par: **Flag / Report** button
- **Moderation**: Admin panel ke **User reports** tab mein admin investigate karke violation resolve ya dismiss kar sakta hai.

### E. Financial Features & Payments Policy
- **Financial Features declaration**: Select **"None"**.
- **Play Billing exemption**:
  Physical goods (groceries, clothing, hardware, food) Google Play Payments policy ke **Section 3** ke tahat Play Billing se exempt hain. Cash on delivery 100% compliant hai.
- **Seller Membership**: Offline policy switch hai, app ke andar koi digital payment gateway ya external payment link nahi hai.

### F. Target Audience & Content Rating (IARC)
- **Target Age**: **18 and older** (local commerce, phone contacts, cash delivery).
- **Families Policy**: "No" (app is not designed for children).
- **News app**: No
- **Government app**: No
- **COVID-19 app**: No

---

## 3. Location Permission: Prominent Disclosure

Google Play Location policy require karta hai ki runtime permission lene se pehle user ko app ke andar dialog dikhaye:
- Danapur Bazaar mein jab user "Use current location" tap karta hai, OS popup aane se pehle **in-app prominent disclosure dialog** aata hai:
  *"Danapur Bazaar accesses your device location in the foreground to verify if your delivery address is within the 500-metre shop delivery radius... Never tracked in background, not shared with advertisers."*
- User cancel karke **Shop pickup** choose kar sakta hai.

---

## 4. Pre-Launch Checklist

- [ ] Supabase migrations 001, 002, 003, 004, 005 apply kiye hue hain.
- [ ] First admin account configure kiya hua hai.
- [ ] Admin panel mein WhatsApp number, support email, aur HTTPS privacy/terms URL set hain.
- [ ] Production signing keystore ke 4 GitHub secrets configured hain.
- [ ] Play Console mein Data Safety form aur App Access details accurately bhare hain.
- [ ] Telegram se `danapur-bazaar.zip` download karke `danapur-bazaar.aab` Google Play Console mein upload kiya hai.
