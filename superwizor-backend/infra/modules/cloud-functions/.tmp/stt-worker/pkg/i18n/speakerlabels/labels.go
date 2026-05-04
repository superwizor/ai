// Package speakerlabels generuje lokalizowane neutralne etykiety dla mówców
// w transkrypcji. Używane gdy diarization zwraca speaker_tag=1,2,3...
// a my potrzebujemy ludzkiej etykiety w języku rozmowy.
//
// Etykiety są neutralne — NIE oznaczają ról (terapeuta/pacjent).
// Role są dedukowane przez LLM podczas analizy raportu.
package speakerlabels

import (
	"fmt"
	"strings"
)

// templates mapuje BCP-47 language tags (lub language prefix) na sformatowany
// pattern dla speaker label. Pattern zawiera "%d" dla numeru speakera.
//
// Klucz: pełny tag (np. "en-US") lub sam język (np. "en") — pełny tag ma priorytet.
// Wartość: format string z %d.
var templates = map[string]string{
	// Polski + slavic
	"pl":    "Osoba %d",
	"cs":    "Osoba %d",
	"sk":    "Osoba %d",
	"ru":    "Человек %d",
	"uk":    "Особа %d",
	"bg":    "Лице %d",
	"sr":    "Особа %d",
	"hr":    "Osoba %d",
	"sl":    "Oseba %d",

	// English
	"en":    "Person %d",

	// Romance
	"es":    "Persona %d",
	"pt":    "Pessoa %d",
	"fr":    "Personne %d",
	"it":    "Persona %d",
	"ro":    "Persoana %d",
	"ca":    "Persona %d",

	// Germanic
	"de":    "Person %d",
	"nl":    "Persoon %d",
	"sv":    "Person %d",
	"no":    "Person %d",
	"nb":    "Person %d",
	"da":    "Person %d",
	"fi":    "Henkilö %d",
	"is":    "Manneskja %d",

	// Hungarian / Estonian / Latvian / Lithuanian
	"hu":    "Személy %d",
	"et":    "Isik %d",
	"lv":    "Persona %d",
	"lt":    "Asmuo %d",

	// Greek
	"el":    "Άτομο %d",

	// Turkish
	"tr":    "Kişi %d",

	// Arabic
	"ar":    "متحدث %d",

	// Hebrew
	"he":    "דובר %d",
	"iw":    "דובר %d",  // legacy code

	// Persian
	"fa":    "گوینده %d",

	// Indic
	"hi":    "व्यक्ति %d",
	"bn":    "ব্যক্তি %d",
	"ta":    "நபர் %d",
	"te":    "వ్యక్తి %d",
	"mr":    "व्यक्ती %d",
	"gu":    "વ્યક્તિ %d",
	"kn":    "ವ್ಯಕ್ತಿ %d",
	"ml":    "വ്യക്തി %d",
	"pa":    "ਵਿਅਕਤੀ %d",
	"ur":    "شخص %d",

	// East Asian
	"ja":    "話者%d",
	"ko":    "화자 %d",
	"cmn":   "说话人 %d",
	"zh":    "说话人 %d",
	"yue":   "說話人 %d",

	// Southeast Asian
	"vi":    "Người %d",
	"th":    "ผู้พูด %d",
	"id":    "Orang %d",
	"ms":    "Orang %d",
	"fil":   "Tao %d",
	"tl":    "Tao %d",

	// African
	"sw":    "Mtu %d",
	"af":    "Persoon %d",
	"am":    "ሰው %d",

	// Caucasian / others
	"ka":    "ადამიანი %d",
	"hy":    "Անձ %d",
	"az":    "Şəxs %d",
	"kk":    "Адам %d",
	"uz":    "Shaxs %d",
}

// Generate zwraca lokalizowaną etykietę dla mówcy o danym tagu (1, 2, 3...).
// Jeśli locale jest nieznany, używa fallback "Speaker %d" (English).
//
// languageCode może być w formacie BCP-47: "pl-PL", "en-US", "cmn-CN",
// albo samego języka: "pl", "en", "cmn". Funkcja akceptuje oba.
func Generate(languageCode string, speakerTag int) string {
	pattern := lookupTemplate(languageCode)
	return fmt.Sprintf(pattern, speakerTag)
}

// GenerateMapping tworzy słownik {speaker_tag → label} dla podanego zbioru tagów.
// Wynik jest deterministycznie posortowany po tagu (1, 2, 3...).
func GenerateMapping(languageCode string, speakerTags []int) map[int]string {
	mapping := make(map[int]string, len(speakerTags))
	for _, tag := range speakerTags {
		mapping[tag] = Generate(languageCode, tag)
	}
	return mapping
}

// lookupTemplate znajduje pattern dla locale.
// Strategia: pełen tag → język → fallback English.
func lookupTemplate(languageCode string) string {
	if languageCode == "" {
		return "Speaker %d" // Actually using English fallback directly because not found
	}

	// 1. Pełny tag
	if pattern, ok := templates[languageCode]; ok {
		return pattern
	}

	// 2. Sam język (przed myślnikiem)
	if idx := strings.IndexAny(languageCode, "-_"); idx > 0 {
		lang := strings.ToLower(languageCode[:idx])
		if pattern, ok := templates[lang]; ok {
			return pattern
		}
	}

	// 3. Może już jest sam język (lowercase)
	if pattern, ok := templates[strings.ToLower(languageCode)]; ok {
		return pattern
	}

	// 4. Fallback English
	return "Speaker %d"
}
