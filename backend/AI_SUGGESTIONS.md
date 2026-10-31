# Wishes and gift suggestions

The Home card selects the same next event as the hero card. Local templates work
without API keys and are labelled Offline inspiration. The user can choose
English/Hindi/Hinglish, Warm/Funny/Short, approximate INR budget and optional
interests. Copy, edit and system share require explicit user action. Suggestions
and preferences are saved per Firebase UID on the device, with bounded caches.
Event name/type/relation/date, occurrence year and options invalidate the cache.

Real AI is optional and implemented through Gemini's REST structured-output API.
Add GEMINI_API_KEY and GEMINI_MODEL to the existing external backend.env, then
restart the local backend. Select a supported model in your Gemini account;
no model subscription, key or paid account has been created by this change.
Keep keys server-side. Do not commit them or pass them in Flutter dart-defines.
No configured key/model means /v1/suggestions returns 503 ai_not_configured.

The app asks for consent before enabling automatic AI requests. Only name,
relationship, event type and chosen language/tone/interests/budget are sent.
Private notes, birth date, UID, phone, photos and audio are not included in the
provider prompt. User-entered data is treated as untrusted prompt data. Responses
are validated and rendered as text; no links or actions are executed from them.
Prices, nearby vendors and availability are not verified and must not be claimed.

GET /v1/suggestions/status and POST /v1/suggestions require Firebase auth.
The POST uses a strict bounded schema, 8s provider timeout, server-only key header,
structured JSON, output validation, and per-UID limits of 6/minute and 30/day.
Limits are in memory and reset on restart; use shared durable quotas before
multi-instance public launch. Rate limits are not a billing cap. AI usage costs
and provider data terms depend on your account; no live provider call was made
without a configured key. Stubbed provider tests do not verify a live model.

On provider failure/timeout/rate limit, the app shows explicitly labelled offline
ideas and retains retry capability. Turning AI off selects offline templates;
previous AI results remain in the bounded per-account local cache. Edited wishes are saved locally for the current event/options and labelled Edited by you. Generating another variant creates a fresh suggestion. Local preference and cache writes are serialized to prevent concurrent updates from losing data.

Tests: backend/test/suggestions.test.js; test/suggestion_test.dart;
test/suggestion_widget_test.dart. Use ordinary flutter test (not a device
integration runner) to avoid uninstalling the user's emulator app.

Provider reference: https://ai.google.dev/gemini-api/docs/structured-output
