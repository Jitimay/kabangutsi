# T2 — Flutter frontend (BLoC): Waves 1, 2, 4, then the call screen

Read `CLAUDE.md` first.

## Before G0 — start now (setup only)
- `flutter create` the project in `frontend/` (org `bi.kabangutsi`, platforms android + web), two entry
  points `lib/main_customer.dart` and `lib/main_agent.dart`.
- Folder structure below, theme, bundled fonts, l10n files (fr, en, rn) with the main UI strings,
  DI (get_it), router (go_router), empty screens for every feature, `frontend/Dockerfile`
  (build Flutter web with `--no-web-resources-cdn`, serve with nginx on port 80 → host 8080).
- **No API, DTO or repository code yet** — that comes from the contracts.
- Update `status/T2.md`. Then wait for G0.

## After G0
Run `git merge main` in your worktree, read everything in `contracts/`, then start Wave 1.

- Branch / worktree: `t2-flutter` → `../kabangutsi-t2`
- You own: `frontend/` and `status/T2.md`
- One Flutter project, two apps (entry points): `lib/main_customer.dart` (Android + web) and
  `lib/main_agent.dart` (web).
- Until G1 you work against a **mock API** generated from `contracts/openapi.yaml` and `ws_events.json`
  (e.g. a mock repository implementation switched by a flag). After G1, switch to the real backend.

## Architecture
```
frontend/lib/
  core/        # theme, router (go_router), DI (get_it), l10n (fr, en, rn), env config
  data/        # API client (dio), WebSocket client, DTOs matching contracts, repositories (+ mock impls)
  features/
    chat/          bloc/ view/ widgets/
    call/          bloc/ view/ widgets/
    ussd/          ...
    model_picker/  ...
    agent_queue/   ...
    call_detail/   ...
    tickets/       ...
    stats/         ...
```
Rules: widgets never call dio directly; every state change goes through a BLoC/Cubit; states are
immutable (`equatable`); repositories are interfaces with real + mock implementations.

Packages: flutter_bloc, equatable, go_router, get_it, dio, web_socket_channel, record, just_audio,
image_picker, flutter_localizations + intl. Add `bloc_test` + `mocktail` for tests.

## Wave 1 — Chat + model picker (customer app)
| ID | Task | Done when |
|---|---|---|
| — | Project setup, theme (BancoBu-style colors but no real logo), l10n fr/en/rn, DI, router | App runs on Android and web |
| F19 | `ModelPickerCubit`: load models with capability badges (text, image, audio, tools); choice kept per session | Badges shown from the API, not hard-coded |
| F20 | Show the `model.switched` notice ("Switched to X: Y cannot read images") | Notice appears when sending an image to a text-only model |
| F2 | `LanguageCubit` (fr/en/rn) for UI strings; reply language follows the backend | All strings exist in 3 languages |
| — | `ChatBloc`: send text, attach image, stream reply (SSE) | Reply appears word by word |

## Wave 2 — Action screens
| ID | Task | Done when |
|---|---|---|
| F5 | Card block flow: identity form (PIN field masked, never logged), confirmation, reference number | Works on mock, then real API |
| F6 | Loan simulator: amount, term → monthly payment + explanation | Values match the API |
| F7 | Complaint: category, description, optional photo → ticket number | Ticket shown |
| F8 | Branch finder: list by province with hours and phone | |
| F14 (UI) | USSD simulator screen: dial `*123#`, numbered menus, backed by `/v1/channels/ussd/inbound` | Same answers as chat |

**→ G1 with T1:** switch the mock for the real API; all 6 request types work by chat in fr, en, rn.

## Wave 4 — Agent dashboard (web)
| ID | Task | Done when |
|---|---|---|
| F10 | `AgentQueueBloc`: live queue via WebSocket, claim a call | Claimed call disappears for other agents |
| F9 | `CallDetailBloc`: transcript + AI summary on pickup | Summary visible immediately |
| F11 | Suggested replies panel (`agent.suggestion`) | Click to insert a suggestion |
| F12 | `StatsCubit`: AI resolution rate, average wait, top intents | Updates live |
| — | `TicketBloc`: ticket list, filters, status update | |

## After G1 — Call screen (with T3 and T1)
| ID | Task | Done when |
|---|---|---|
| F1 | `CallBloc` states: idle → listening → thinking → speaking → handedOff → ended. Record mic (`record`), send audio, play TTS (`just_audio`), live transcript | Full voice call on a real Android phone |

## Offline rules
- Bundle all fonts in `assets/fonts` (no `google_fonts` runtime download).
- Web build: `flutter build web --no-web-resources-cdn`. Test with Wi-Fi off.
- Backend URL from build-time config (`--dart-define=API_URL=...`), never hard-coded.

## Tests
`bloc_test` for every BLoC/Cubit (at least happy path + error), widget test for the call screen states.
