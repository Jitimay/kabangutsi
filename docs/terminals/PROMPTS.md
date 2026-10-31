# Prompts to start each terminal

Open one terminal per block. Run the command, then paste the prompt into Claude.

## T0 Lead (start now)
Command:
```
cd ~/codes/kabangutsi && claude
```
Prompt:
```
You are T0 Lead for the Kabangutsi project. Read CLAUDE.md and docs/terminals/T0-lead.md. Do Wave 0 until every item of the G0 checklist is done. Work only in the folders you own. Keep status/T0.md updated after every task. When G0 is complete, write "G0 reached — run git merge main" in status/T0.md and commit.
```

## T2 Flutter (start now, setup only)
Command:
```
cd ~/codes/kabangutsi-t2 && claude
```
Prompt:
```
You are T2 Flutter for the Kabangutsi project. Read CLAUDE.md and docs/terminals/T2-flutter.md. Do only the "Before G0" setup now: no API, DTO or repository code. Work only in frontend/ and status/T2.md. Keep status/T2.md updated after every task and commit your work on branch t2-flutter. When the setup is done, stop and wait for G0.
```

## T3 Voice (start now, tests only)
Command:
```
cd ~/codes/kabangutsi-t3 && claude
```
Prompt:
```
You are T3 Voice for the Kabangutsi project. Read CLAUDE.md and docs/terminals/T3-voice.md. Do Step 1 now: test speech-to-text and text-to-speech models for French, English and Kirundi on this CPU-only machine. Put scripts and results in voice/experiments/ and a summary table in status/T3.md. Work only in voice/ and status/T3.md, and commit on branch t3-voice. Do not build the service before G0.
```

## T4 Channels + documents (start now, tests only)
Command:
```
cd ~/codes/kabangutsi-t4 && claude
```
Prompt:
```
You are T4 Channels and Documents for the Kabangutsi project. Read CLAUDE.md and docs/terminals/T4-channels-docs.md. Do only the "Before G0" tests now: GSM modem SMS, WhatsApp bridge, PaddleOCR on fictional documents, one WeasyPrint PDF. Put scripts in sms/experiments/, whatsapp/experiments/ and ocr/experiments/, and record results in status/T4.md. Work only in your folders and commit on branch t4-channels. Do not write adapter code before G0.
```

## T1 Backend (WAIT until status/T0.md says "G0 reached")
Command:
```
cd ~/codes/kabangutsi-t1 && claude
```
Prompt:
```
You are T1 Backend for the Kabangutsi project. First run git merge main to get the contracts. Then read CLAUDE.md, docs/terminals/T1-backend.md and every file in contracts/. Start Wave 1. Work only in backend/ (not backend/channels/) and status/T1.md. Implement the contracts exactly. Keep status/T1.md updated after every task, run pytest before each update, and commit on branch t1-backend.
```

## After G0: message for T2, T3 and T4
Paste this into the T2, T3 and T4 terminals when G0 is reached:
```
G0 is reached. Run git merge main, read every file in contracts/, then continue with the "After G0" part of your instructions.
```
