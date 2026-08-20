# Reviewed audio cues

This folder contains audio generated ahead of time with Edge-TTS and copied into the app bundle as `Audio/`. The app only plays these bundled files; it does not use Apple speech synthesis or call a TTS service at runtime.

The included Edge-TTS tool generates every fixed cue ahead of time:

```bash
./scripts/setup_edge_tts.sh
.edge-tts-venv/bin/python scripts/generate_edge_tts.py
```

Edit `scripts/edge_tts_cues.json` to change the voice, text, rate, or pitch. Run with `--force` to replace existing recordings and `--verify` to check coverage without contacting the service.

Required scene and question cues:

- `scene_choose_helper`, `question_fox_bakes`
- `scene_gather_ingredients`, `question_panpan_strawberries`
- `scene_mix_together`, `question_milk_and_stir`
- `scene_birthday_surprise`, `question_sing_for_maomiao`

Required pre-story conversation cues:

- `welcome_greeting`
- `welcome_mood_question`
- `welcome_mood_happy`, `welcome_mood_calm`, `welcome_mood_sleepy`
- `welcome_ready`
- `welcome_returning`

For every checkpoint, add its four hint cue IDs from `StoryCatalog.swift`, plus:

- `success_<checkpoint-id>` and `recast_<checkpoint-id>`
- `english_hint_<checkpoint-id>` (generated with `en-US-AnaNeural`)
- `please_repeat_unheard`, `please_repeat_uncertain`, `audio_problem`, and `parent_help`
- `story_complete`

For the most natural result, use one warm native-Mandarin speaker throughout, leave small conversational pauses, and export mono AAC `.m4a` files at a consistent loudness. AI-generated recordings can also be used, but every line should be listened to and approved before it is bundled.

Do not start the supervised child pilot until every generated cue has been listened to and editorially approved.
