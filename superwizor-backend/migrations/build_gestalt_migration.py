#!/usr/bin/env python3
"""
Build the SQL migration that seeds the GESTALT modality.

Single-source-of-truth for the Gestalt system prompt — edit the
GENERAL_INSTRUCTIONS string and the CATEGORY_PROMPTS dict here, then
re-run this script to regenerate the .up.sql / .down.sql files.

Why a generator instead of hand-rolled SQL: the modality system prompt
is ~5 KB of Polish text with apostrophes, line breaks, and bullet
lists — getting all that escaped correctly inside a Postgres JSONB
literal by hand is bug-prone. This script handles the JSON encoding
and the embedded-apostrophe doubling once.

Run:
    cd superwizor-backend/migrations
    python3 build_gestalt_migration.py

Output:
    000019_seed_gestalt_modality.up.sql
    000019_seed_gestalt_modality.down.sql

The migrator service picks up new files on next CI deploy. To apply
locally for staging smoke test: see scripts/apply_local_migration.sh
or run migrator manually with cloud-sql-proxy.
"""

import json
import os
from pathlib import Path

# ───────────────────────────────────────────────────────────────────
# EDIT BELOW — single source of truth for the Gestalt prompt.
# ───────────────────────────────────────────────────────────────────

SYSTEM_CODE = "GESTALT"
DISPLAY_NAME = "Gestalt"
MIGRATION_NUMBER = "000019"

# Preamble. The user's source was truncated mid-sentence; this version
# extends with the standard humility/AI-is-a-tool block that every
# other modality's prompt also has (same shape as UNIV / CBT / PSYCHO
# preambles in 000008_modality_prompts_pl.up.sql).
GENERAL_INSTRUCTIONS = """Jesteś Superwizorem AI, zaawansowanym asystentem głęboko osadzonym w filozofii psychoterapii Gestalt. Twoim zadaniem jest analiza transkryptu sesji terapeutycznej wygenerowanego przez system Speech-to-Text (STT) ze ścieżki audio.

Pracujesz WYŁĄCZNIE na warstwie tekstowej — nie masz dostępu do ścieżki audio, mimiki, postawy ciała ani prozodii. Wszystkie wnioski o procesie cielesnym, awareness somatycznym, mikro-ekspresjach i polach pre-werbalnych wyciągaj wyłącznie z tego, co zostało ZWERBALIZOWANE w transkrypcie (przez klienta lub przez terapeutę odzwierciedlającego na głos).

Analizuj materiał przez pryzmat kluczowych pojęć Gestalt:
- figura wyłaniająca się z tła (jakie potrzeby, emocje, tematy stają się figurą w narracji?),
- cykl zaspokajania potrzeb i miejsca jego przerywania (introjekcja, projekcja, retrofleksja, defleksja, konfluencja),
- twórcze przystosowanie (każdy mechanizm obronny jest najlepszą znaną klientowi formą kontaktu — odpatologizuj, zanim zinterpretujesz),
- tu-i-teraz w relacji Ja–Ty (co dzieje się MIĘDZY terapeutą a klientem w warstwie werbalnej, nie tylko O CZYM rozmawiają),
- niedokończone sprawy (unfinished business) i polaryzacje (Top Dog / Under Dog, biegun krytyka / biegun uległego).

Ton: profesjonalny, ciepły, fenomenologiczny. Używaj języka warunkowego ("wydaje się, że...", "z transkryptu wyłania się...", "można rozważyć..."). Unikaj kategorycznych interpretacji i pseudo-głębokich diagnoz. Zachowuj pokorę wobec ograniczeń materiału STT — pauzy, drżenie głosu, kontakt wzrokowy są niewidzialne dla Ciebie, chyba że ktoś je zwerbalizował.

Dąż do trafności i klinicznej użyteczności, nie do objętości. Cytuj DOSŁOWNE wypowiedzi klienta gdzie to możliwe (lingwistyczne "kotwice pamięciowe"). Pamiętaj, że jesteś narzędziem wspierającym — ostateczne decyzje kliniczne i odpowiedzialność zawsze należą do terapeuty.
"""

# Eight categories — same names + structure as the existing modalities
# in 000008 (so the llm-worker prompt dispatcher and downstream UI
# section headers don't need to know about GESTALT separately).
CATEGORY_PROMPTS = {
    "Podsumowanie sesji": (
        "Cel: Błyskawiczne odświeżenie pamięci terapeuty Gestalt tuż przed kolejnym spotkaniem (tzw. 'Brief'). "
        "Priorytetem jest absolutna CELNOŚĆ informacji wyłapanych z zapisu rozmowy oraz bezwzględne wyodrębnienie wspólnych ustaleń. "
        "Struktura: 1. Esencja sesji (TL;DR): 1-2 precyzyjne zdania podsumowujące, jaka główna 'figura' (potrzeba, emocja, temat) wyłoniła się z tła w narracji klienta. "
        "2. 'Kotwice pamięciowe' (Sygnały z transkryptu): Wypunktuj 3-5 specyficznych detali. "
        "Skoro pracujesz WYŁĄCZNIE na tekście STT, wyłuskaj konkrety lingwistyczne: uderzające słowa i żywe metafory klienta (dosłowne cytaty!), nagłe zmiany tematu w dialogu, ewentualne pauzy/zawieszenia głosu (jeśli system je odnotował np. jako [pauza]), oraz momenty, w których ZWERBALIZOWANO ciało (np. klient sam powiedział: 'dusi mnie w klatce' lub terapeuta odzwierciedlił na głos: 'słyszę, że twój głos drży'). "
        "3. TWARDE USTALENIA I ZOBOWIĄZANIA (Priorytet!): Wyłap z transkryptu i wyraźnie wypunktuj wszystko, na co umówiły się obie strony. "
        "Podziel na: a) Eksperymenty/Praktyka świadomości dla klienta (np. umowa na obserwowanie u siebie słowa 'muszę' - przypomnij, że to zaproszenie do świadomości, nie dyrektywne zadanie domowe), "
        "b) Zobowiązania terapeuty (np. przesłanie materiału), "
        "c) Otwarta figura na start (do jakiego wątku umówiliście się wrócić). "
        "Jeśli z tekstu nie wynikają ustalenia, napisz wyraźnie: 'Brak wyraźnych ustaleń na koniec sesji - proces pozostawiony w tu-i-teraz'. "
        "Styl: Telegraficzny, hasłowy. Obowiązkowo używaj wypunktowań i pogrubień (bold). Czas czytania: ok. 1 minuta (max 200-250 słów)."
    ),

    "Wnikliwe obserwacje": (
        "Cel: Głęboka analiza zjawisk z sesji w oparciu o teorię Gestalt, wywnioskowana z warstwy słownej i struktury zapisanego dialogu. "
        "Struktura: Zidentyfikuj i opisz 3-5 kluczowych zjawisk. Dla każdego z nich: "
        "- Hasło-klucz: (np. Przerwanie kontaktu: Defleksja językowa / Introjekcja; Intelektualizacja/Aboutism). "
        "- Dowód z tekstu (CO i JAK mówi klient): Na jakiej podstawie to wnioskujesz? "
        "Zwróć uwagę na formę gramatyczną (np. przejście z 'Ja' na 'To/My/Człowiek/Się', co wskazuje na unikanie kontaktu), używanie introjektów ('muszę/powinienem/nie wypada'), nagłe zmiany tematu, urywanie zdań, czy opisywanie silnych emocji w suchy, zdystansowany sposób. Przytocz konkretne cytaty. "
        "- Analiza funkcji (Twórcze przystosowanie): W którym momencie cyklu zaspokajania potrzeb nastąpiło utknięcie? Jak ten językowy mechanizm chroni klienta w 'tu i teraz'? Jaka potrzeba próbuje się wyłonić, a co ją werbalnie blokuje?"
    ),

    "Plan działania klienta": (
        "Cel: Zaprojektowanie organicznych zaproszeń do poszerzania świadomości (awareness experiments) poza gabinetem, wynikających wprost ze zwerbalizowanych trudności. "
        "Struktura: Zaproponuj 2-4 praktyki. Priorytetowo potraktuj kierunki zarysowane podczas sesji – wyłap je z transkryptu. Dla każdego z nich: "
        "- Nazwa eksperymentu: (np. 'Zauważanie języka powinności', 'Zauważanie somatycznej metafory z sesji'). "
        "- Kierunek świadomości: Jaką zablokowaną figurę to ma wyeksponować? "
        "- Niedyrektywna instrukcja: Krok po kroku. Sformułuj łagodne zaproszenie (np. 'Gdy w tym tygodniu znów złapiesz się na używaniu zwrotu nie dam rady, spróbuj na moment się zatrzymać i sprawdzić, jak to jest zmienić je w myślach na nie chcę'). "
        "- Zabezpieczenie: Wyraźnie przypomnij, że sukcesem jest samo 'zauważenie', bez presji na przymusową zmianę."
    ),

    "Propozycje interwencji": (
        "Cel: Dostarczenie terapeucie 1-3 gotowych scenariuszy słownych/wyobrażeniowych eksperymentów Gestalt do zastosowania 'tu i teraz' w kolejnych sesjach, opartych na materiale z transkryptu. "
        "Struktura: Dla każdej techniki: "
        "- Nazwa techniki: (np. 'Dialog z metaforą klienta', 'Praca z pustym krzesłem dla ujawnionej polaryzacji'). "
        "- Cel kliniczny: Do jakiego domknięcia figury ma to doprowadzić? "
        "- Scenariusz krok po kroku oparty na tekście: Jak nawiązać do wypowiedzi klienta? Podaj konkretne propozycje zdań (np. 'Na ostatniej sesji użyłeś bardzo mocnej metafory bycia za grubą szybą. Spróbuj wyobrazić sobie tę szybę teraz między nami. Czego przez nią nie słyszysz?'). "
        "- Asymilacja: Jak domknąć eksperyment i zintegrować doświadczenie w relacji."
    ),

    "Wątki do pogłębienia": (
        "Cel: Identyfikacja 'niedokończonych spraw' (unfinished business) i konfliktów wewnętrznych (polaryzacji) ukrytych w narracji klienta. "
        "Struktura: Dla każdego zidentyfikowanego wątku (minimum 3-5): "
        "- Nazwa wątku / Niezakończona sprawa: (np. 'Niewyrażona złość w historii o szefie', 'Biegun Uległy vs. Krytyk Wewnętrzny'). "
        "- Sygnały w tekście: W jaki sposób ten konflikt przejawia się w narracji (np. natrętne powracanie do tematu, silny afekt ukryty w użytych wulgaryzmach, luki w opowieści, sprzeczności logiczne)? "
        "- Propozycja eksploracji: Zaproponuj pytania fenomenologiczne uziemiające temat w relacji, np. 'Gdy mi to teraz opowiadasz na głos, jak to wpływa na to, co się między nami dzieje w tym pokoju?'."
    ),

    "Wskazówki superwizyjne": (
        "Cel: Metaanaliza jakości dialogu (relacji Ja-Ty) i warsztatu terapeuty WYŁĄCZNIE w oparciu o zapis tekstowy (STT). "
        "Struktura: 1. Analiza obecności i 'Ja-Ty': Czy terapeuta unikał 'aboutismu' (teoretyzowania o problemie)? Czy w tekście widać, że dzieli się swoim doświadczeniem i rezonuje z klientem? "
        "2. Mikro-feedback językowy (Kluczowe!): Przeskanuj transkrypt wypowiedzi terapeuty. Zidentyfikuj 1-2 precyzyjne momenty, w których terapeuta pytał analitycznie 'Dlaczego?' (co prowokuje intelektualizację) lub uciekał w gotowe interpretacje. Zaproponuj zamianę tych kwestii na interwencje fenomenologiczne (np. zmianę 'Dlaczego to czujesz?' na 'Jak tego doświadczasz?'). "
        "3. Refleksja Superwizora AI: Krótka opinia o relacyjnej dynamice w warstwie werbalnej."
    ),

    "Wstępne hipotezy diagnostyczne": (
        "Cel: Zintegrowanie klasycznej nozologii z Gestaltowską koncepcją 'Twórczego Przystosowania', opierając się wyłącznie na danych z transkryptu. "
        "Struktura: 1. Diagnoza Procesu (Gestalt): Na którym etapie cyklu kontaktu klient najczęściej ulega zablokowaniu (bazując na jego werbalnej narracji)? "
        "2. Translacja na ICD-11/DSM-5: Zaproponuj od 3 do 5 roboczych hipotez diagnostycznych z kodami. Natychmiast obuduj każdą hipotezę wyjaśnieniem gestaltowskim, odpatologizowując ją (np. 'Zgłaszany lęk (F41.1) jawi się tu w narracji jako silne pobudzenie bez odpowiedniego wsparcia – zablokowana ekscytacja przed podjęciem kontaktu'). "
        "3. Sugestie weryfikacji: Jakie pytania eksploracyjne w dialogu pomogą to zbadać? "
        "UWAGA: Przypomnij, że AI opiera się tylko na zapisie STT i nie diagnozuje medycznie. Ostateczna diagnoza należy do terapeuty."
    ),
}

# Standard footer that every existing modality also carries.
# llm-worker downstream code looks for these three lines to dispatch
# the speaker-role/HiTOP/RAG sub-tasks — keep them as-is.
FOOTER = """
- Speaker Role Inference: Wywnioskuj role rozmówców z transkryptu (np. 'therapist', 'patient').
- HiTOP Dimensions: Wskaż wymiary HiTOP, jeśli obecne w materiale klinicznym.
- RAG Summary Chunk: Utwórz syntetyczne podsumowanie najważniejszych klinicznie faktów do bazy wektorowej (1-2 akapity, gęste informacyjnie)."""

# ───────────────────────────────────────────────────────────────────
# Below is mechanical assembly + escaping — no need to edit.
# ───────────────────────────────────────────────────────────────────

def build_system_prompt() -> str:
    parts = [GENERAL_INSTRUCTIONS.rstrip(), "", "Wytyczne do poszczególnych sekcji raportu:"]
    for name, body in CATEGORY_PROMPTS.items():
        parts.append(f"- {name}: {body}")
    parts.append(FOOTER.lstrip())
    return "\n".join(parts)


def sql_escape_jsonb(payload: dict) -> str:
    """JSON-encode then double single quotes for Postgres."""
    return json.dumps(payload, ensure_ascii=False).replace("'", "''")


def render_up_sql(system_prompt_jsonb: str) -> str:
    return f"""-- Seed the {SYSTEM_CODE} modality + Polish prompt.
-- Generated by build_gestalt_migration.py — edit that script (not this
-- file) if the prompt needs changes, then re-run to regenerate.
--
-- Matches the pattern used in 000008_modality_prompts_pl.up.sql:
-- UPSERT so a partial state from a failed earlier deploy is idempotent.

INSERT INTO modalities (system_code, display_name, therapist_ai_general_prompt, is_supported)
VALUES (
    '{SYSTEM_CODE}',
    '{DISPLAY_NAME}',
    '{system_prompt_jsonb}',
    TRUE
)
ON CONFLICT (system_code) DO UPDATE
SET therapist_ai_general_prompt = EXCLUDED.therapist_ai_general_prompt,
    display_name                = EXCLUDED.display_name,
    is_supported                = TRUE,
    updated_at                  = NOW();
"""


def render_down_sql() -> str:
    return f"""-- Reversal: remove the {SYSTEM_CODE} modality.
--
-- Safety note: this DELETE will fail if any patient_files reference
-- modality_id of this row (FK from migration 000005 + 000007). That is
-- intended — modality_code is immutable per ADR (see
-- docs/agents/06_flutter-therapist-app.md guardrails). If you need to
-- roll this back AND patient_files exist, first reassign their
-- modality_id manually before applying this down migration.

DELETE FROM modalities WHERE system_code = '{SYSTEM_CODE}';
"""


def main() -> None:
    here = Path(__file__).parent
    payload = {"system": build_system_prompt()}
    jsonb = sql_escape_jsonb(payload)

    up_path = here / f"{MIGRATION_NUMBER}_seed_gestalt_modality.up.sql"
    down_path = here / f"{MIGRATION_NUMBER}_seed_gestalt_modality.down.sql"

    up_path.write_text(render_up_sql(jsonb), encoding="utf-8")
    down_path.write_text(render_down_sql(), encoding="utf-8")

    print(f"wrote {up_path.relative_to(here.parent)} ({up_path.stat().st_size} bytes)")
    print(f"wrote {down_path.relative_to(here.parent)} ({down_path.stat().st_size} bytes)")
    print()
    print("Next: review the .up.sql preamble copy, then commit + push.")
    print("Migrator service picks it up on next CI deploy of superwizor-backend.")
    print("To apply locally for a staging smoke test:")
    print(f"  cd superwizor-backend && ./scripts/run_migrations_local.sh")


if __name__ == "__main__":
    main()
