# Radni Nalozi: Projekt "macOS Optimizator"

**Klasifikacijska Oznaka Projeta (KLASA):** `100-02/24-001`

---

### Radni Nalog 1: Dokumentacija - README.md

**Urudžbeni Broj (URBROJ):** `100-02/24-001-RN.01-001`
**Datum:** 31.12.2025.
**Predmet:** Izrada i popunjavanje `README.md` datoteke

**Zadaci:**
1.  Napisati detaljan opis funkcionalnosti skripte za optimizaciju.
2.  Precizno objasniti mehanizam za uklanjanje skrivenih macOS snapshotova i naglasiti da ne utječe na standardne Time Machine sigurnosne kopije.
3.  Dodati jasno i istaknuto upozorenje da skripta u potpunosti uklanja Spotlight indeksiranje.
4.  Uključiti preporuku za korištenje alternativnih launchera poput SOL-a, s pripadajućom poveznicom na njihovu web stranicu ili repozitorij.

**Status:** **Dovršeno**

---

### Radni Nalog 2: Dokumentacija - Elaborat o Nadogradnji

**Urudžbeni Broj (URBROJ):** `100-02/24-001-RN.01-002`
**Datum:** 24.05.2024.
**Predmet:** Izrada i popunjavanje `ELABORAT-O-NADOGRADNJI.md`

**Zadaci:**
1.  Definirati i opisati budući zadatak: Uklanjanje sistemskog i aplikacijskog spellcheckera.
2.  Definirati i opisati budući zadatak: Optimizacija Time Machine backupa isključivanjem cache direktorija.
3.  Definirati i opisati budući zadatak: Osiguravanje da su ključne skrivene korisničke datoteke (`.config`, `dotfiles`, `.ssh`) uključene u Time Machine backup.

**Status:** **Dovršeno**

---

### Radni Nalog 3: Implementacija - Uklanjanje Spellcheckera

**Urudžbeni Broj (URBROJ):** `100-02/24-001-RN.01-003`
**Datum:** 24.05.2024.
**Predmet:** Implementacija funkcionalnosti za uklanjanje sistemskog spellcheckera

**Zadaci:**
1.  Analizirati metode za sigurno i reverzibilno onemogućavanje `AppleSpell.service`.
2.  Implementirati kod unutar glavne skripte koji izvršava navedeno onemogućavanje.
3.  Testirati utjecaj na performanse i potencijalne sigurnosne rizike na ciljanim macOS verzijama.
4.  Ažurirati `README.md` s novom funkcionalnošću.

**Status:** **Nije započeto**

---

### Radni Nalog 4: Implementacija - Optimizacija Time Machine (Cache)

**Urudžbeni Broj (URBROJ):** `100-02/24-001-RN.01-004`
**Datum:** 24.05.2024.
**Predmet:** Implementacija funkcionalnosti za isključivanje cache direktorija iz Time Machine backupa

**Zadaci:**
1.  Identificirati sve standardne lokacije cache direktorija (`~/Library/Caches`, `/Library/Caches`, itd.).
2.  Napisati skriptu koja rekurzivno dodjeljuje `com.apple.backupd.nobackup` metadata tag navedenim direktorijima.
3.  Osigurati da skripta ne dira postojeće korisničke postavke za izuzimanje iz Time Machinea.
4.  Ažurirati `README.md` s novom funkcionalnošću.

**Status:** **Nije započeto**

---

### Radni Nalog 5: Implementacija - Optimizacija Time Machine (Uključivanje Dotfiles)

**Urudžbeni Broj (URBROJ):** `100-02/24-01-005`
**Datum:** 24.05.2024.
**Predmet:** Implementacija provjere i osiguravanja backupa ključnih skrivenih datoteka

**Zadaci:**
1.  Provjeriti zadano ponašanje Time Machinea u vezi s backupom skrivenih datoteka i direktorija u korisničkom `home` folderu (npr. `~/.config`, `~/.ssh`, `~/.gitconfig`).
2.  Ako se utvrdi da ih Time Machine preskače, istražiti i implementirati metodu za njihovo pouzdano uključivanje.
3.  Dokumentirati proces i rezultate u `ELABORAT-O-NADOGRADNJI.md`.

**Status:** **Nije započeto**
