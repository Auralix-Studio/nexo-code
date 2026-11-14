# Privacy Policy

## 1. Controller and contact

The party responsible for developing Nexo and for the personal data processed by its server is Auralix Studio ("the Developer"), based in Huancayo, Peru.

- Email: alessandrovillogas@outlook.es
- WhatsApp: +51 907 924 307 (app's Support section)

## 2. Legal framework

This Policy is governed by **Law No. 29733, Personal Data Protection Law**, and its Regulation, approved by **Supreme Decree No. 016-2024-JUS**, as well as other applicable Peruvian rules. The terms "personal data", "processing", "data subject" and "processor" have the meaning given by those rules.

## 3. How Nexo works

The app talks **only to the Nexo API** (https://api.nexo.aurx.pro), the Developer's own server. The API signs in to the UPLA systems (SIGMA, Intranet and Language Center) **on your behalf**, reads your information and returns it organized. The app no longer connects to those systems directly.

- **Your password is never stored on the server.** It is used once to sign in to UPLA and then discarded.
- What the server does keep are the **sessions the university issues** at sign-in (SIGMA token, Intranet cookies and Language Center token), **encrypted with AES-256-GCM**, to answer your next requests without asking for your password again. They are deleted when you sign out.
- The app keeps your credentials **only on your device**, in its secure storage, to sign in again when the university session expires.

## 4. Data processed

**a) Credentials and session.** User code and password (only in transit to UPLA; never stored on the server), the encrypted university sessions and Nexo's access tokens.

**b) Identity.** Code, names and the address of the institutional photo published by UPLA. The photo is downloaded directly from the university's servers.

**c) Academic data.** Grades, schedule, curriculum progress, terms, enrollment and language courses, as UPLA makes them available to each account.

**d) Financial data.** Installments, payments, debts, fees and payment history.

**e) Institutional Wi-Fi credential.** Read from SIGMA only when you ask for it and shown to you; it is **never stored** or logged on the server.

**f) Teacher module data.** If you are a teacher: your sections, the student lists of those sections (names, code, institutional photo) and the grades and attendance you record.

**g) Optional feature data.** Directory access granted by administrators, guardian data (DNI and protected PIN) and their consent, what you choose to share with integrations and the permissions you approve (see section 7).

**h) Security and technical data.** IP address, date and time of requests, app version and the audit log of sensitive actions (sign-in, teacher records, directory lookups, consent changes, acceptance of these documents).

**i) Local preferences and usage.** Theme, language, time format, notification and startup settings, attendance drafts and dismissed notices. Stored only on your device.

Nexo does not request additional sensitive data, does not access your location, contacts, camera or microphone, and does not build profiles for commercial purposes.

## 5. Purposes

Data is processed only to:

- Sign you in and keep your session in the UPLA services through the Nexo API.
- Show you your academic and administrative information in an organized way, also offline.
- Schedule reminders and local notifications for classes and payments on your device, and show home screen widgets.
- In the teacher module, let teachers view and record attendance and grades for their sections.
- Provide the optional features you or an administrator turn on.
- Protect the service: limit abuse, detect improper access and be able to show who accessed what.
- Check whether a new app version exists and answer your support requests.

## 6. Legal basis

Processing is based on your consent, given when you accept this Policy, and because it is necessary to provide the service you request. In the teacher module, student data is processed within the academic relationship the university already grants the teacher in SIGMA, and for the same purposes. Optional features require their own consent.

You can withdraw your consent at any time by signing out and no longer using the app, or by turning off each optional feature.

## 7. Optional features

- **Student directory.** Only accounts an administrator grants access to can see it. Each record viewed is logged with the code of whoever opened it.
- **Guardian access.** A parent or guardian can view the student's information with their DNI and a PIN, only with the corresponding consent, which can be revoked.
- **Calendar (.ics).** If you turn it on, a private link with your schedule is created so you can subscribe from any calendar app. Only a fingerprint of the link is stored; you can renew or turn it off.
- **"Connect with Nexo".** A third-party app can request access with a code; it only receives the permissions you approve (profile, schedule) and you can revoke it whenever you want. What that app does is governed by its own policy.
- **Grade alerts (coming soon).** If you turn them on, the server will periodically check for changes in your grades using your university session and send you a notification. It is optional: you can turn it off in the app's notification settings or by signing out.

## 8. Recipients, processors and transfers

Nexo does not sell, rent or give away your personal data, shows no advertising and includes no third-party analytics or tracking tools. Only these take part:

- **UPLA services** (SIGMA, Intranet, Language Center and the photo server): they receive your credentials and requests through the Nexo API to return your own information. Their processing is governed by the university's policies.
- **Microsoft Azure** (Microsoft Corporation), as processor: hosts the Nexo API on Azure Container Apps, in the **Chile Central** region.
- **MongoDB Atlas** (MongoDB, Inc.), as processor: cloud database that stores the account, the encrypted sessions, the audit log and the optional feature data.
- **Google Firebase** (Google LLC): Firebase App Check is planned to make sure only the official app calls the API and, if you turn on grade alerts, Firebase Cloud Messaging to deliver them. They only receive technical device and notification data.
- **GitHub** (Microsoft Corporation): receives a technical request to check whether a new version exists. No academic information or credentials are sent to it.
- **WhatsApp or your email provider**, only if you decide to contact support, and only with the information you send.

Since these providers have servers outside Peru (for example, in Chile and the United States), using Nexo involves a **cross-border flow** of personal data, carried out under Law No. 29733 and its Regulation, which you consent to by accepting this Policy.

## 9. Storage and retention

- **On the server:** university sessions are stored encrypted and deleted when you sign out or when they expire. Your academic and financial information is fetched from UPLA on each request and, at most, kept in memory for a few minutes to answer faster; it is not stored in the database, except what you choose to share through optional features. Your basic record (code and names), the teacher's sections used to check their access, the audit log and the record of acceptance of these documents are kept for as long as needed for security purposes and to prove legal compliance.
- **On the device:** credentials and session data are kept in the operating system's secure storage (Keychain, Keystore or the Windows equivalent). In the web version, the session is kept only in memory. Academic information is kept in a local database, with no encryption beyond what the operating system provides. Attendance drafts are kept for at most two days or until recorded.
- **Signing out deletes** the university sessions on the server and, on the device, the credentials, cached information and drafts. Uninstalling the app deletes all its local data.

## 10. Security

- All communications use encrypted connections (HTTPS/TLS).
- University sessions are encrypted on the server with AES-256-GCM and passwords are never stored.
- The API limits the number of requests to stop abuse and records sensitive actions in an audit log.
- Firebase App Check is planned to be required so that only the official app can call the API.

Security also depends on screen lock, system updates and the user's care. No measure is foolproof.

## 11. Data subject rights

Under Law No. 29733, you can exercise your rights of information, access, rectification, cancellation and objection, and any others the current rules recognize.

- You can view your data in the app, update it in the UPLA systems, delete your sessions from the server and the local data by signing out, and turn off each optional feature.
- For any request, including deleting what the server keeps about you, write to alessandrovillogas@outlook.es. You will be answered within the legal deadlines.
- If you believe your rights were not respected, you can file a complaint with the **National Authority for Personal Data Protection** of the Ministry of Justice and Human Rights.

Academic information (for example, a grade) can only be corrected by the university in its official systems.

## 12. Minors

Nexo is aimed at university students and teachers. Processing of minors' data is subject to the special rules of Law No. 29733 and its Regulation; children under fourteen must not use the app without their parents' or guardians' permission.

## 13. Duty of confidentiality

Teachers, and anyone with directory or guardian access, who access student data through Nexo must keep it confidential and use it only for the authorized purpose, under article 17 of Law No. 29733. Capturing, spreading or sharing that data with third parties is forbidden.

## 14. Changes to this Policy

If the way data is processed changes significantly, this Policy will be updated with its new version and date. The current version is published by the Nexo API, so the app detects it without needing an update, shows you a summary of the changes and asks for a new acceptance before continuing.
