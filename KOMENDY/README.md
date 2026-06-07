# 🎛️ SKRÓTY KOMEND

Folder z gotowymi skrótami deweloperskimi. Używaj wersji skróconej (sam numer) lub pełnej nazwy pliku.

### 📋 Szybki spis komend

| # | Komenda (krótka) | Co robi? |
| :--- | :--- | :--- |
| **0** | `source ./KOMENDY/0` | 📂 Przenosi terminal do głównego katalogu projektu |
| **1** | `./KOMENDY/1` | 🚀 Odpala lokalną bazę, migracje i backend (5 usług) |
| **2** | `./KOMENDY/2` | 🧪 Uruchamia lokalne testy E2E |
| **3** | `./KOMENDY/3` | 💻 Uruchamia aplikację Flutter jako apkę macOS |
| **4** | `./KOMENDY/4` | 📲 Wgrywa aplikację Flutter na podłączony telefon |
| **5** | `./KOMENDY/5` | 🍏 Buduje paczkę iOS i otwiera Xcode (App Store / TestFlight) |
| **6** | `./KOMENDY/6` | 🌐 Uruchamia stronę WWW lokalnie |

---

### 🛠️ Dwa najczęstsze scenariusze

#### A. Chcę pokodzić i sprawdzić apkę lokalnie:
1. **Terminal 1**: Odpal backend i zostaw otwarty:
   ```bash
   ./KOMENDY/1
   ```
2. **Terminal 2** (nowa zakładka: `Cmd + T`): Wgraj apkę na telefon:
   ```bash
   ./KOMENDY/4
   ```

#### B. Chcę sprawdzić, czy testy przechodzą:
1. **Terminal 1**: Upewnij się, że backend działa (`./KOMENDY/1`).
2. **Terminal 2** (nowa zakładka: `Cmd + T`): Odpal testy E2E:
   ```bash
   ./KOMENDY/2
   ```

---
> 💡 **Wskazówka**: Jeśli dostaniesz błąd uprawnień, wpisz raz w głównym katalogu: `chmod +x KOMENDY/*`
