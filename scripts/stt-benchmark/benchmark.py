#!/usr/bin/env python3
"""Harness porownawczy dostawcow STT dla polskich sesji terapeutycznych.

Powstal po wycofaniu Deepgrama (2026-07-31): nova-3 deterministycznie
przestawal emitowac slowa w polowie nagrania, mimo ze widzial pelna
dlugosc pliku. Zaden test jakosci tego nie zlapal, bo mierzylismy WER na
krotkich fixture'ach, a nie POKRYCIE dlugiego nagrania. Stad dwie
metryki pierwszej kategorii w tym harnessie:

  coverage_pct  — gdzie konczy sie ostatnie slowo wzgledem dlugosci
                  audio. To jest metryka, ktora zlapalaby nova-3.
  speaker_count — ilu mowcow wykryl dostawca vs ile bylo naprawde.
                  Diaryzacja jest twardym wymaganiem: Chirp 3 nie
                  obsluguje jej dla pl-PL, wiec dzis rozdziela mowcow
                  klasteryzacja LLM w dol pipeline'u.

WER swiadomie NIE jest liczony: nie mamy referencyjnych transkrypcji.
Harness mierzy to, co da sie zmierzyc bez ground truth, i zapisuje
pelne surowe odpowiedzi do recznej oceny jakosci tekstu.

Zaleznosci: tylko stdlib dla dostawcow API. Whisper wymaga doinstalowania
(patrz README) i jest pomijany, gdy go brak.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))


# ── pomocnicze ────────────────────────────────────────────────────────


def audio_duration_s(path):
    """Dlugosc audio przez pelne zdekodowanie.

    ffprobe czyta dlugosc z naglowka, a nasze FLAC-i z telefonu miewaja
    total_samples=0 w STREAMINFO (strumieniowy zapis nie zna dlugosci z
    gory). Dekodowanie do /dev/null zawsze zwraca prawde — i to wlasnie
    ta prawda jest mianownikiem coverage_pct.
    """
    out = subprocess.run(
        ["ffmpeg", "-i", path, "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    last = None
    for m in re.finditer(r"time=(\d+):(\d\d):(\d\d(?:\.\d+)?)", out):
        last = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    return last


def _http(url, data=None, headers=None, method=None, timeout=900):
    req = urllib.request.Request(url, data=data, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def _secret(name, project="superwizor-ai-25ecd"):
    r = subprocess.run(
        ["gcloud", "secrets", "versions", "access", "latest",
         "--secret", name, "--project", project],
        capture_output=True, text=True,
    )
    return r.stdout.strip() if r.returncode == 0 else None


def _key(env_var, secret_name):
    """Klucz z ENV, a jak go nie ma — z Secret Managera."""
    return os.environ.get(env_var) or _secret(secret_name)


def _multipart(fields, files):
    """Body multipart/form-data bez requests."""
    b = uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                % (b, k, v)).encode()
    for k, (fn, blob, ctype) in files.items():
        out += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n"
                "Content-Type: %s\r\n\r\n" % (b, k, fn, ctype)).encode()
        out += blob + b"\r\n"
    out += ("--%s--\r\n" % b).encode()
    return out, "multipart/form-data; boundary=%s" % b


def summarize(words, duration):
    """Wspolny ksztalt wyniku: pokrycie + rozklad mowcow.

    `words` to lista dictow {end, speaker}. Kazdy adapter normalizuje do
    tego ksztaltu, zeby porownanie bylo miedzy dostawcami, a nie miedzy
    ich formatami JSON.
    """
    last = max((w["end"] for w in words), default=0.0)
    spk = {}
    for w in words:
        s = w.get("speaker")
        if s is None:
            continue
        spk.setdefault(str(s), 0)
        spk[str(s)] += 1
    return {
        "word_count": len(words),
        "last_word_end_s": round(last, 2),
        "coverage_pct": round(100.0 * last / duration, 1) if duration else None,
        "speaker_count": len(spk) if spk else None,
        "words_per_speaker": spk or None,
    }


# ── dostawcy ──────────────────────────────────────────────────────────
#
# Kazdy adapter zwraca (words, raw). `words` to lista {end, speaker}.
# Brak diaryzacji => speaker=None => speaker_count=None (a nie 0, bo
# "nie wspiera" to co innego niz "wykryl zero mowcow").


def run_deepgram(case, path, _cfg):
    """Deepgram nova-3 — punkt odniesienia, to z czego wychodzimy."""
    key = _key("DEEPGRAM_API_KEY", "deepgram-api-key")
    if not key:
        raise RuntimeError("brak DEEPGRAM_API_KEY")
    q = ("model=nova-3&language=%s&diarize=true&punctuate=true"
         "&smart_format=true&mip_opt_out=true" % case.get("language", "pl"))
    st, body = _http(
        "https://api.eu.deepgram.com/v1/listen?" + q,
        data=open(path, "rb").read(),
        headers={"Authorization": "Token " + key,
                 "Content-Type": "audio/" + case.get("format", "flac")},
    )
    raw = json.loads(body)
    if st != 200:
        raise RuntimeError("HTTP %s: %s" % (st, str(raw)[:200]))
    alt = raw["results"]["channels"][0]["alternatives"][0]
    words = [{"end": w["end"], "speaker": w.get("speaker")}
             for w in alt.get("words", [])]
    return words, raw


def run_chirp3(case, path, cfg):
    """Google Chirp 3 — obecna produkcja.

    Wymaga GCS (BatchRecognize), bo Recognize inline ma limit 60 s, a
    nasze nagrania sa dluzsze. Plik ladowany do bucketa roboczego z
    BENCH_GCS_PREFIX, kasowany po odczycie.

    UWAGA: diarizationConfig jest tu swiadomie NIEwysylany dla pl-PL —
    recognizer eu/_ zwraca 400 "Recognizer does not support feature:
    speaker_diarization". To nie jest ograniczenie harnessu, tylko
    Chirpa, i wlasnie dlatego szukamy alternatywy.
    """
    prefix = cfg.get("gcs_prefix") or os.environ.get("BENCH_GCS_PREFIX")
    if not prefix:
        raise RuntimeError("ustaw BENCH_GCS_PREFIX=gs://<bucket>/<sciezka>")
    project = cfg.get("project", "superwizor-ai-25ecd")
    uri = "%s/%s-%s" % (prefix.rstrip("/"), case["id"], os.path.basename(path))
    subprocess.run(["gcloud", "storage", "cp", path, uri, "--project", project],
                   capture_output=True, check=True)
    try:
        tok = subprocess.run(["gcloud", "auth", "print-access-token"],
                             capture_output=True, text=True, check=True).stdout.strip()
        lang = case.get("language", "pl")
        bcp = {"pl": "pl-PL", "en": "en-US", "uk": "uk-UA"}.get(lang, lang)
        req = {
            "config": {
                "autoDecodingConfig": {},
                "model": "chirp_3",
                "languageCodes": [bcp],
                "features": {"enableAutomaticPunctuation": True,
                             "enableWordTimeOffsets": True},
            },
            "files": [{"uri": uri}],
            "recognitionOutputConfig": {"inlineResponseConfig": {}},
        }
        st, body = _http(
            "https://eu-speech.googleapis.com/v2/projects/%s/locations/eu/"
            "recognizers/_:batchRecognize" % project,
            data=json.dumps(req).encode(),
            headers={"Authorization": "Bearer " + tok,
                     "Content-Type": "application/json"},
        )
        op = json.loads(body)
        if st != 200:
            raise RuntimeError("HTTP %s: %s" % (st, str(op)[:300]))
        deadline = time.time() + 1800
        while time.time() < deadline:
            st, body = _http("https://eu-speech.googleapis.com/v2/" + op["name"],
                             headers={"Authorization": "Bearer " + tok})
            raw = json.loads(body)
            if raw.get("done"):
                break
            time.sleep(5)
        else:
            raise RuntimeError("operacja Chirpa nie zakonczyla sie w 30 min")
        if raw.get("error"):
            raise RuntimeError(str(raw["error"])[:300])
        words = []
        for _uri, v in raw.get("response", {}).get("results", {}).items():
            for r in v.get("transcript", {}).get("results", []):
                for a in r.get("alternatives", [])[:1]:
                    for w in a.get("words", []):
                        words.append({
                            "end": float(str(w.get("endOffset", "0s")).rstrip("s") or 0),
                            "speaker": w.get("speakerLabel") or None,
                        })
        return words, raw
    finally:
        subprocess.run(["gcloud", "storage", "rm", uri, "--project", project],
                       capture_output=True)


def run_speechmatics(case, path, cfg):
    """Speechmatics — batch job + polling.

    Host domyslnie EU (asr.api.speechmatics.com stoi w UE). Dla klientow
    z wymogiem konkretnej jurysdykcji Speechmatics daje osobne hosty —
    nadpisz SPEECHMATICS_HOST.
    """
    key = _key("SPEECHMATICS_API_KEY", "speechmatics-api-key")
    if not key:
        raise RuntimeError("brak SPEECHMATICS_API_KEY")
    host = os.environ.get("SPEECHMATICS_HOST", "https://asr.api.speechmatics.com")
    cfgj = {
        "type": "transcription",
        "transcription_config": {
            "language": case.get("language", "pl"),
            "diarization": "speaker",
            "operating_point": cfg.get("operating_point", "enhanced"),
        },
    }
    body, ctype = _multipart(
        {"config": json.dumps(cfgj)},
        {"data_file": (os.path.basename(path), open(path, "rb").read(),
                       "audio/" + case.get("format", "flac"))},
    )
    st, resp = _http(host + "/v2/jobs", data=body,
                     headers={"Authorization": "Bearer " + key, "Content-Type": ctype})
    j = json.loads(resp)
    if st not in (200, 201):
        raise RuntimeError("HTTP %s: %s" % (st, str(j)[:300]))
    job_id = j["id"]
    deadline = time.time() + 1800
    while time.time() < deadline:
        st, resp = _http("%s/v2/jobs/%s" % (host, job_id),
                         headers={"Authorization": "Bearer " + key})
        status = json.loads(resp).get("job", {}).get("status")
        if status == "done":
            break
        if status in ("rejected", "expired"):
            raise RuntimeError("job %s: %s" % (job_id, status))
        time.sleep(5)
    else:
        raise RuntimeError("job %s nie skonczyl sie w 30 min" % job_id)
    st, resp = _http("%s/v2/jobs/%s/transcript?format=json-v2" % (host, job_id),
                     headers={"Authorization": "Bearer " + key})
    raw = json.loads(resp)
    words = []
    for r in raw.get("results", []):
        if r.get("type") != "word":
            continue
        alts = r.get("alternatives") or [{}]
        words.append({"end": float(r.get("end_time", 0)),
                      "speaker": alts[0].get("speaker")})
    return words, raw


def run_elevenlabs(case, path, _cfg):
    """ElevenLabs Scribe v1.

    Domyslny host to endpoint rezydencji EU. Jest on dostepny wylacznie
    w planach z EU data residency — na zwyklym koncie zwroci 401/404.
    To nie jest blad harnessu: brak dzialajacego hosta EU oznacza, ze
    dostawca nie spelnia twardego wymagania i tak wlasnie ma zostac
    zaraportowany. Do testu bez rezydencji: ELEVENLABS_HOST=
    https://api.elevenlabs.io
    """
    key = _key("ELEVENLABS_API_KEY", "elevenlabs-api-key")
    if not key:
        raise RuntimeError("brak ELEVENLABS_API_KEY")
    host = os.environ.get("ELEVENLABS_HOST", "https://api.eu.residency.elevenlabs.io")
    lang = {"pl": "pol", "en": "eng", "uk": "ukr"}.get(case.get("language", "pl"))
    fields = {"model_id": "scribe_v1", "diarize": "true",
              "timestamps_granularity": "word"}
    if lang:
        fields["language_code"] = lang
    if case.get("expected_speakers"):
        fields["num_speakers"] = str(case["expected_speakers"])
    body, ctype = _multipart(
        fields,
        {"file": (os.path.basename(path), open(path, "rb").read(),
                  "audio/" + case.get("format", "flac"))},
    )
    st, resp = _http(host + "/v1/speech-to-text", data=body,
                     headers={"xi-api-key": key, "Content-Type": ctype})
    raw = json.loads(resp)
    if st != 200:
        raise RuntimeError("HTTP %s (host=%s): %s" % (st, host, str(raw)[:300]))
    words = [{"end": float(w.get("end", 0)), "speaker": w.get("speaker_id")}
             for w in raw.get("words", []) if w.get("type", "word") == "word"]
    return words, raw


def run_whisper(case, path, cfg):
    """Whisper large-v3 lokalnie (faster-whisper) + opcjonalnie pyannote.

    Whisper SAM NIE MA diaryzacji — to model transkrypcyjny. Bez
    pyannote adapter zwraca speaker=None, czyli w raporcie wyjdzie
    "brak diaryzacji". Tak ma byc: uczciwy obraz to "Whisper + osobny
    diaryzator", a nie udawanie, ze to jedno pudelko.
    """
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        raise RuntimeError("brak faster-whisper (pip install faster-whisper)")
    model = WhisperModel(cfg.get("whisper_model", "large-v3"),
                         device=cfg.get("whisper_device", "cpu"),
                         compute_type=cfg.get("whisper_compute", "int8"))
    segments, _info = model.transcribe(path, language=case.get("language", "pl"),
                                       word_timestamps=True, vad_filter=False)
    words, texts = [], []
    for seg in segments:
        texts.append(seg.text)
        for w in (seg.words or []):
            words.append({"end": float(w.end), "speaker": None, "word": w.word})

    turns = []
    try:
        from pyannote.audio import Pipeline
        hf = os.environ.get("HUGGINGFACE_TOKEN")
        if hf:
            pipe = Pipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1", use_auth_token=hf)
            diar = pipe(path)
            for turn, _, spk in diar.itertracks(yield_label=True):
                turns.append((turn.start, turn.end, spk))
            for w in words:
                for s, e, spk in turns:
                    if s <= w["end"] <= e:
                        w["speaker"] = spk
                        break
    except ImportError:
        pass

    raw = {"text": "".join(texts), "words": words,
           "diarization_turns": turns,
           "diarization": "pyannote-3.1" if turns else None}
    return words, raw


PROVIDERS = {
    "deepgram": run_deepgram,
    "chirp3": run_chirp3,
    "speechmatics": run_speechmatics,
    "elevenlabs": run_elevenlabs,
    "whisper": run_whisper,
}

# Rezydencja danych — twarde wymaganie. Wartosci opisowe, bo "EU" znaczy
# co innego u kazdego dostawcy i harness ma to wypisac wprost w raporcie.
EU_STATUS = {
    "deepgram": "api.eu.deepgram.com — endpoint EU",
    "chirp3": "locations/eu — recognizer i przetwarzanie w UE",
    "speechmatics": "asr.api.speechmatics.com w UE; hosty per-jurysdykcja na zyczenie",
    "elevenlabs": "wymaga planu z EU data residency (api.eu.residency.elevenlabs.io)",
    "whisper": "self-hosted — rezydencja z definicji nasza",
}


# ── uruchomienie ──────────────────────────────────────────────────────


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=os.path.join(HERE, "manifest.json"))
    ap.add_argument("--providers", default="chirp3,speechmatics,elevenlabs,whisper",
                    help="lista po przecinku; dostepne: " + ",".join(PROVIDERS))
    ap.add_argument("--cases", default="", help="filtr id sesji po przecinku")
    ap.add_argument("--out", default=os.path.join(HERE, "results"))
    args = ap.parse_args()

    cases = json.load(open(args.manifest))
    if args.cases:
        want = set(args.cases.split(","))
        cases = [c for c in cases if c["id"] in want]
    providers = [p.strip() for p in args.providers.split(",") if p.strip()]
    for p in providers:
        if p not in PROVIDERS:
            sys.exit("nieznany dostawca: %s (dostepne: %s)" % (p, ",".join(PROVIDERS)))

    os.makedirs(os.path.join(args.out, "raw"), exist_ok=True)
    rows = []

    for case in cases:
        path = case["path"]
        if not os.path.isabs(path):
            path = os.path.join(HERE, path)
        if not os.path.exists(path):
            print("POMIJAM %s — brak pliku %s" % (case["id"], path))
            continue
        dur = audio_duration_s(path)
        print("\n=== %s (%.1f s, oczekiwani mowcy: %s) ==="
              % (case["id"], dur or 0, case.get("expected_speakers", "?")))
        for name in providers:
            row = {"case": case["id"], "provider": name,
                   "audio_duration_s": round(dur, 2) if dur else None,
                   "expected_speakers": case.get("expected_speakers"),
                   "eu_residency": EU_STATUS.get(name)}
            t0 = time.time()
            try:
                words, raw = PROVIDERS[name](case, path, case.get("config", {}))
                row.update(summarize(words, dur))
                row["latency_s"] = round(time.time() - t0, 1)
                rp = os.path.join(args.out, "raw", "%s_%s.json" % (name, case["id"]))
                with open(rp, "w") as f:
                    json.dump(raw, f, ensure_ascii=False, indent=1)
                row["raw"] = os.path.relpath(rp, args.out)
                exp = case.get("expected_speakers")
                got = row.get("speaker_count")
                row["diarization_ok"] = (None if got is None else got == exp)
                print("  %-14s pokrycie %5s%%  slow %4s  mowcy %s%s  %ss"
                      % (name,
                         row.get("coverage_pct"), row.get("word_count"),
                         got if got is not None else "brak",
                         "" if row["diarization_ok"] is None
                         else (" OK" if row["diarization_ok"] else " ZLE (ocz. %s)" % exp),
                         row["latency_s"]))
            except Exception as e:  # noqa: BLE001 — raport ma przezyc kazda awarie
                row["error"] = str(e)[:400]
                row["latency_s"] = round(time.time() - t0, 1)
                print("  %-14s BLAD: %s" % (name, row["error"]))
            rows.append(row)

    res = os.path.join(args.out, "results.json")
    with open(res, "w") as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)

    print("\n" + "=" * 78)
    print("%-10s %-14s %8s %7s %8s %9s" % ("SESJA", "DOSTAWCA", "POKRYCIE",
                                           "SLOW", "MOWCY", "CZAS"))
    print("-" * 78)
    for r in rows:
        if r.get("error"):
            print("%-10s %-14s %s" % (r["case"], r["provider"], "BLAD: " + r["error"][:44]))
            continue
        mark = "" if r.get("diarization_ok") is None else (" OK" if r["diarization_ok"] else " ZLE")
        print("%-10s %-14s %7s%% %7s %6s%-3s %8ss"
              % (r["case"], r["provider"], r.get("coverage_pct"),
                 r.get("word_count"),
                 r.get("speaker_count") if r.get("speaker_count") is not None else "brak",
                 mark, r.get("latency_s")))
    print("=" * 78)
    print("wyniki: %s   surowe odpowiedzi: %s/raw/" % (res, args.out))
    print("\nPOKRYCIE to metryka, ktora zlapalaby nova-3 (sesja 7: 24%).")
    print("Jakosc samego tekstu oceniaj recznie z raw/ — nie mamy transkrypcji")
    print("referencyjnych, wiec WER nie jest liczony.")


if __name__ == "__main__":
    main()
