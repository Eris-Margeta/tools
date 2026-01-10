---
**TVORNICA ELEKTRONIČKIH JEDINICA I LOGIKE – TEJL d.o.o.**
**Sektor za Sistemsku Integraciju i Razvoj**

**Klasa:** 025-01/25-01
**Urbroj:** 251-10-02-25-01 (Rev. 1)
**Datum:** 31.12.2025.

**PREDMET: Inicijalni elaborat o razvoju projekta "amazing-mac-optimizer"**

---

### **1.0 UVOD I OBRAZLOŽENJE**

Ovaj dokument predstavlja tehničku i operativnu specifikaciju za razvoj alata "amazing-mac-optimizer", dizajniranog za dubinsku optimizaciju, oslobađanje prostora na disku i poboljšanje privatnosti i performansi na Apple macOS sustavima.

### **2.0 CILJEVI PROJEKTA**

1.  **Optimizacija Diskovnog Prostora:** Uklanjanje skrivenih i automatski generiranih APFS snapshotova koji zauzimaju značajan prostor bez znanja korisnika.
2.  **Poboljšanje Performansi i Privatnosti:** Kompletno uklanjanje Spotlight servisa i indeksa, namijenjeno korisnicima koji koriste alternativne launchere (npr. Sol).
3.  **Povećanje Sigurnosti Sustava:** Onemogućavanje "system-wide" spellcheckera koji može predstavljati sigurnosni rizik.
4.  **Optimizacija Time Machine Sigurnosnih Kopija:** Ubrzavanje i smanjenje veličine Time Machine backupa isključivanjem nepotrebnih "cache" direktorija te osiguravanje uključivanja ključnih skrivenih konfiguracijskih datoteka.

### **3.0 TEHNIČKA SPECIFIKACIJA I STANDARDI**

#### **3.1 Arhitektura Sustava**
Sustav će biti implementiran kao CLI (Command-Line Interface) alat u obliku shell skripte.

#### **3.2 Tehnologije**
*   **Programski Jezik:** Shell Script (Bash/Zsh)
*   **Baza Podataka:** Nije primjenjivo
*   **Framework:** Standardne macOS komandne linije (tmutil, defaults, etc.)

### **4.0 PREGLED STATUSA IMPLEMENTACIJE**

*   **Cjelina 1: Inicijalizacija Projekta i Osnovna Optimizacija:** **ZAVRŠENO**.
    *   Implementirano uklanjanje skrivenih APFS snapshotova.
    *   Implementirano potpuno uklanjanje Spotlight servisa.
    *   Kreirana osnovna dokumentacija (README.md).

### **5.0 PLAN DALJNJIH AKTIVNOSTI**

**Cjelina 2: Napredna Optimizacija Sustava i Time Machine Backup-a (SLJEDEĆI PRIORITET)**

*   **2.1. Upravljanje Spellcheckerom:**
    *   `2.1.a.` Implementirati logiku za potpuno i trajno onemogućavanje "system-wide" spellcheckera putem `defaults write` komandi.
    *   `2.1.b.` Istražiti i implementirati metodu za granularno onemogućavanje spellcheckera na razini pojedinačnih aplikacija, gdje je to moguće.

*   **2.2. Optimizacija Time Machine Backup-a (Izuzeci):**
    *   `2.2.a.` Identificirati sve standardne i uobičajene putanje za "cache" direktorije (npr. `~/Library/Caches`, `~/.cache`).
    *   `2.2.b.` Kreirati funkciju unutar skripte koja automatski dodaje detektirane "cache" direktorije u listu izuzetaka za Time Machine (`tmutil addexclusion`).

*   **2.3. Optimizacija Time Machine Backup-a (Uključivanje):**
    *   `2.3.a.` Definirati listu ključnih skrivenih datoteka i direktorija u korisničkom "home" folderu koji su kritični za korisnika (npr. `.config`, `.ssh`, `.gitconfig`, `.zshrc`, i ostali dotfiles).
    *   `2.3.b.` Implementirati mehanizam koji provjerava i osigurava da navedene stavke *nisu* na listi izuzetaka te da će biti uključene u Time Machine backup.

---
**Sastavio:**
AI Asistent, Sektor za Sistemsku Integraciju

**Odobrio:**
Operater, Odbor za Standardizaciju i Razvoj TEJL-a
