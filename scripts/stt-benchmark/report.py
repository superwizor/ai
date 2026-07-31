#!/usr/bin/env python3
"""Scala wyniki ze wszystkich przebiegow w jedna tabele.

Liczy metryki z surowych odpowiedzi w */raw/, nie z results.json.
Powod jest praktyczny: rownolegle przebiegi (--out) nadpisuja sobie
results.json, a pliki raw maja unikalne nazwy i przezywaja wszystko.
results.json sluzy juz tylko do wyciagniecia bledow i czasu odpowiedzi.

Poza pokryciem raportuje dwie metryki, ktore okazaly sie potrzebne po
pierwszym pelnym przebiegu:

  slow/s    — Speechmatics na zle otagowanym jezykowo nagraniu mial
              pokrycie 99%, ale 0,81 slowa na sekunde zamiast ~2,9.
              Pokrycie patrzy tylko, gdzie jest OSTATNIE slowo, wiec
              dziura w srodku jest dla niego niewidoczna.
  max luka  — najdluzsza przerwa miedzy slowami, lapie zgubiony
              fragment przy poprawnej koncowce.

Znaczniki poza dlugoscia audio sa odrzucane z pokrycia i liczone
osobno (kolumna ZLE-TS): Chirp potrafi wyemitowac pojedynczy uszkodzony
endOffset (8486,92 s w nagraniu 820 s), ktory bez tego dawal pokrycie
1034,7%.
"""

import argparse
import glob
import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
PROV_ORDER = ["chirp3", "deepgram", "speechmatics", "elevenlabs", "whisper"]


def audio_duration_s(path):
    out = subprocess.run(["ffmpeg", "-i", path, "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    last = None
    for m in re.finditer(r"time=(\d+):(\d\d):(\d\d(?:\.\d+)?)", out):
        last = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    return last


def parse_raw(path, provider):
    """(słowa jako [(start, end, speaker)], nazwa modelu) z surowej odpowiedzi."""
    r = json.load(open(path))
    out = []
    if provider == "deepgram":
        a = r["results"]["channels"][0]["alternatives"][0]
        for w in a.get("words", []):
            out.append((w["start"], w["end"], w.get("speaker")))
    elif provider == "elevenlabs":
        for w in r.get("words", []):
            if w.get("type", "word") == "word":
                out.append((float(w["start"]), float(w["end"]), w.get("speaker_id")))
    elif provider == "speechmatics":
        for x in r.get("results", []):
            if x.get("type") == "word":
                alts = x.get("alternatives") or [{}]
                out.append((float(x["start_time"]), float(x["end_time"]),
                            alts[0].get("speaker")))
    elif provider == "chirp3":
        for doc in r.get("_transcripts", []):
            off = doc.get("_chunk_offset_s", 0)
            for res in doc.get("results", []):
                for alt in res.get("alternatives", [])[:1]:
                    for w in alt.get("words", []):
                        s = off + float(str(w.get("startOffset", "0s")).rstrip("s") or 0)
                        e = off + float(str(w.get("endOffset", "0s")).rstrip("s") or 0)
                        out.append((s, e, w.get("speakerLabel")))
    elif provider == "whisper":
        for w in r.get("words", []):
            out.append((0.0, float(w["end"]), w.get("speaker")))
    out.sort(key=lambda t: t[1])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", default="results,results-chirp,results-chirp2,"
                                      "results-chirp3,results-en,results-flac")
    ap.add_argument("--manifest", default=os.path.join(HERE, "manifest.json"))
    args = ap.parse_args()

    cases = {c["id"]: c for c in json.load(open(args.manifest))}
    durations = {}
    for cid, c in cases.items():
        p = c["path"] if os.path.isabs(c["path"]) else os.path.join(HERE, c["path"])
        durations[cid] = audio_duration_s(p) if os.path.exists(p) else None

    # meta z results.json: bledy i czasy. Pozniejszy katalog wygrywa.
    meta = {}
    for d in args.dirs.split(","):
        p = os.path.join(HERE, d.strip(), "results.json")
        if os.path.exists(p):
            for row in json.load(open(p)):
                meta[(row["case"], row["provider"])] = row

    # surowe odpowiedzi: nazwa pliku to <dostawca>_<sesja>.json
    raws = {}
    for d in args.dirs.split(","):
        for p in sorted(glob.glob(os.path.join(HERE, d.strip(), "raw", "*.json"))):
            base = os.path.basename(p)[:-5]
            prov, _, cid = base.partition("_")
            if prov in PROV_ORDER and cid in cases:
                raws[(cid, prov)] = p  # pozniejszy katalog nadpisuje

    print("%-17s %-13s %8s %7s %7s %8s %6s %7s %8s"
          % ("SESJA", "DOSTAWCA", "POKRYCIE", "SLOW", "SLOW/s", "MAX LUKA",
             "ZLE-TS", "MOWCY", "CZAS"))
    print("-" * 92)
    for cid in cases:
        exp = cases[cid].get("expected_speakers")
        dur = durations.get(cid)
        printed = False
        for prov in PROV_ORDER:
            m = meta.get((cid, prov))
            if (cid, prov) not in raws:
                if m and m.get("error"):
                    print("%-17s %-13s  BLAD: %s" % (cid, prov, m["error"][:48]))
                    printed = True
                continue
            w = parse_raw(raws[(cid, prov)], prov)
            if not w:
                print("%-17s %-13s  brak slow" % (cid, prov))
                printed = True
                continue
            tol = (dur or 0) * 1.02
            sane = [e for _s, e, _sp in w if not dur or e <= tol]
            bogus = len(w) - len(sane)
            last = max(sane) if sane else 0
            gaps = [w[i + 1][0] - w[i][1] for i in range(len(w) - 1)]
            spk = set(sp for _s, _e, sp in w if sp is not None)
            ok = "" if not spk else (" OK" if len(spk) == exp else " ZLE")
            print("%-17s %-13s %7s%% %7d %7.2f %7.1fs %6d %3s%-3s %7ss"
                  % (cid, prov,
                     round(100.0 * last / dur, 1) if dur else "—",
                     len(w), len(w) / dur if dur else 0,
                     max(gaps) if gaps else 0, bogus,
                     len(spk) if spk else "brak", ok,
                     (m or {}).get("latency_s", "—")))
            printed = True
        if printed:
            print()
    print("ZLE-TS = znaczniki czasu poza dlugoscia audio, odrzucone z pokrycia.")
    print("SLOW/s i MAX LUKA lapia to, czego POKRYCIE nie widzi: zgubiony")
    print("srodek nagrania przy poprawnie zakonczonej koncowce.")


if __name__ == "__main__":
    main()
