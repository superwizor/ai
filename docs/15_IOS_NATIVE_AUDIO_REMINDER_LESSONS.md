---
type: Technical Design
title: Lekcje z natywnym przypomnieniem audio na iOS (ReminderManager)
description: Zapis problemów, rozwiązań i best-practices po wielodniowej walce z odtwarzaniem natywnego przypomnienia w trakcie sesji nagraniowej na iOS z poziomu Fluttera.
resource: file:///Users/maciekckoklormam91/Desktop/Inne/02_APP%20-%20Superwizor%20AI/docs/15_IOS_NATIVE_AUDIO_REMINDER_LESSONS.md
tags: [ios, audio, flutter, przypomnienie, background, avfoundation]
timestamp: 2026-07-20T02:45:00+02:00
---

# Zmagania z natywnym dźwiękiem przypomnienia na iOS

Ten dokument jest zapisem wielodniowej "drogi przez mękę", by wymusić na iOSie prawidłowe i spójne odtwarzanie małego, trywialnego wręcz dzwonka przypominającego terapeucie o mijającym czasie sesji. 

Dlaczego taki trywiał urósł do rangi "boss fightu"? Ponieważ Flutter nałożył własną paczkę abstrakcji na ekosystem iOS, co stworzyło cztery nakładające się na siebie pułapki techniczne.

## Problem 1: Gdzie jest ten plik audio?! (Ścieżki assetów)
**Kontekst:** Włożyliśmy `SFX_session_end_2.mp3` do folderu `assets/sounds/` w projekcie Flutterowym i zdefiniowaliśmy go w `pubspec.yaml`. Następnie próbowaliśmy odtworzyć to po stronie Swift używając klasycznego Apple'owego API: `Bundle.main.url(forResource: "SFX_session_end_2", withExtension: "mp3")`. 
**Symptom:** AVAudioPlayer dostawał `nil` zamiast pliku i w ogóle się nie inicjował. Cisza z głośnika.
**Przyczyna:** System budowania Fluttera ukrywa assety zdeklarowane w `pubspec.yaml`. Co gorsza, struktura katalogu `flutter_assets/` zmienia się w zależności od tego czy budujemy paczkę w trybie *Debug*, *Profile* czy *Release*. Statyczne hardcodowanie ścieżek zawsze ostatecznie zawodziło.
**Rozwiązanie (The Right Way):** Zastosowanie interfejsu `FlutterDartProject.lookupKey(forAsset:)`. Jest to oficjalne narzędzie z iOS Flutter SDK, które potrafi zajrzeć do środka skomplikowanego, flutterowego bundle'a i wyciągnąć dokładną natywną ścieżkę (Key). Następnie wystarczyło przepiąć logikę w naszym `ReminderManager.swift`:
```swift
let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/sounds/SFX_session_end_2.mp3")
let url = Bundle.main.url(forResource: assetKey, withExtension: nil)
```

## Problem 2: Tryb Debug vs iPhone (JIT i Crash Signal 9)
**Kontekst:** Często diagnozowaliśmy aplikację klikając `Play` (Run) wprost z Xcode, chcąc zobaczyć logi z Swift w konsoli. Aplikacja natychmiast po połączeniu wyrzucała `App terminated due to signal 9` po czym debugger tracił połączenie z telefonem.
**Przyczyna:** Od iOS 14+ (i mocniej w iOS 26), polityki bezpieczeństwa drastycznie utrudniają "Just-In-Time" (JIT) kompilację na fizycznych urządzeniach. Domyślny start z Xcode (na architekturze debug, którą pod spodem korzysta Flutter) napotyka blokadę wykonywania dynamicznego kodu na żywym urządzeniu i natychmiast ubija aplikację.
**Rozwiązanie:** Trzeba było zaprzestać używania fizycznego "Play" z Xcode. Zamiast tego zrobiliśmy specjalny workflow: 
1. Całkowite czyszczenie projektu: `flutter clean` by usunąć nieważne bundle cache.
2. Zbudowanie/Puszczenie aplikacji z CLI korzystając z prekompilowanego trybu profile: `flutter run --profile -d <id_urządzenia>`.
*Tylko tryb profile lub release buduje Dart w formie AOT (Ahead of Time), co nie łamie restrykcji JIT na prawdziwym iPhonie.*

## Problem 3: Zawieszenie w tle i zablokowany ekran
**Kontekst:** Skrypt w Dart był odpowiedzialny za wyliczanie "czy minęło już X minut?". Niestety po uśpieniu ekranu Flutter zamrażał Dart VM i nie pozwalał pętli sprawdzać czasu, przez co przypomnienia milczały.
**Rozwiązanie:** 
1. Dodano klucz `UIBackgroundModes` z flagą `audio` w `Info.plist`. 
2. Całość logiki "tykającego zegara" została zaimplementowana po stronie Swift w `ReminderManager.swift` wykorzystując natywny `DispatchQueue.main.asyncAfter`.
Dzięki temu, w połączeniu z tym że proces audio jest podtrzymywany z powodu trwającego "nagrywania" (mikrofon działa w tle), natywny kod Swift w ogóle się nie usypia. Zliczanie czasu żyje poza warstwą Fluttera i potrafi odpalić plik audio nawet jak system całkowicie zminimalizował interfejs Fluttera.

## Problem 4: Konflikt mikrofonu (AVAudioSession)
**Kontekst:** Odpalenie standardowego dźwięku na iOS potrafi natychmiast ubić inny dźwięk nagrywający (np. mikrofon podczas sesji, z którego korzysta Record/Deepgram).
**Rozwiązanie:** Do poprawnego zaimplementowania przypomnienia, AVAudioSession podczas odpalania powiadomienia musiał zostać wycelowany w tryb wielozadaniowości. W naszym natywnym kodzie ustawiamy opcje `[.duckOthers, .defaultToSpeaker]`, a kategoria całej aplikacji to `.playAndRecord`. Dzięki temu nagranie może sobie trwać swoim trybem i nie przerywa się, podczas gdy nasz dzwonek tylko na moment cicho "nadpisuje" kanał głośnika.

---
**Status:** Działa na iOS 26+ i obsługuje tryb Profile. Wzór do wykorzystania na przyszłość przy próbach obsługi audio/wibracji przy wyłączonym ekranie.
