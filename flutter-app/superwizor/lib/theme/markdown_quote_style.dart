// Wspólny styl cytatu blokowego w Markdownie.
//
// Cytat z sesji wygląda tak samo wszędzie, gdzie się pojawia: w raporcie,
// w zapisie rozmowy z AI i w samym czacie. To nie jest kwestia estetyki —
// terapeuta czyta te same słowa klienta w trzech miejscach i musi je
// rozpoznawać jako cytat, a nie jako komentarz narzędzia.
//
// Do 20.08.2026 styl istniał tylko w report_screen.dart. Zapis rozmowy
// nie definiował `blockquote`, więc dostawał domyślny z flutter_markdown:
// jasny, prawie biały blok z ciemnym tekstem, wstawiony w ciemny motyw.
// Wyglądał jak błąd renderowania, bo w praktyce nim był.
//
// Wartości pochodzą z raportu i są tam od dawna zweryfikowane wzrokowo,
// więc to raport jest źródłem prawdy, a nie odwrotnie.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'euphire_theme.dart';

/// Styl tekstu wewnątrz cytatu.
const TextStyle kQuoteTextStyle = TextStyle(
  fontFamily: 'Montserrat',
  fontStyle: FontStyle.italic,
  fontSize: 13.5,
  height: 1.6,
  color: Color(0xD9FAFAFA), // frostWhite @ 85%
);

/// Tło i belka cytatu: ledwo widoczna poświata plus bursztynowy akcent
/// po lewej. Belka niesie tu całą robotę — to ona mówi „to są cudze
/// słowa", zanim czytelnik zacznie czytać.
BoxDecoration get kQuoteDecoration => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      border: Border(
        left: BorderSide(
          color: EuphireColors.ember.withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
    );

/// Wcięcie wewnątrz cytatu.
const EdgeInsets kQuotePadding = EdgeInsets.fromLTRB(12, 8, 12, 8);

/// Dokłada styl cytatu do gotowego arkusza.
///
/// `copyWith` zamiast budowania arkusza od zera: każdy ekran ma własną
/// typografię akapitów i nagłówków, a wspólny ma być wyłącznie cytat.
MarkdownStyleSheet withQuoteStyle(MarkdownStyleSheet base) => base.copyWith(
      blockquote: kQuoteTextStyle,
      blockquoteDecoration: kQuoteDecoration,
      blockquotePadding: kQuotePadding,
    );
