Place real Polish-speech FLAC sample audio here as `sample.flac` for full
pipeline testing. The shell-based E2E test (`tests/e2e/test_full_session.sh`)
picks it up automatically.

The Go-based E2E test reads from `superwizor-backend/tests/e2e/testdata/sample.flac`
instead — drop the same file there too if you run that one.

We standardised on FLAC because Chirp 3 / `eu-speech.googleapis.com`
returns INTERNAL errors for M4A/AAC inputs (see git log
`6b25848 fix(stt-worker): switch pipeline to FLAC ...` for context).
Re-encode any other source with:

    ffmpeg -i in.m4a -c:a flac -ac 1 -ar 16000 sample.flac

Mono (`-ac 1`) at 16 kHz (`-ar 16000`) is what Chirp 3 prefers; stereo and
other sample rates work but lower transcription confidence.
