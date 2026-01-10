---
**TVORNICA ELEKTRONIČKIH JEDINICA I LOGIKE – TEJL d.o.o.**
**Odbor za Standardizaciju i Normizaciju**

**Klasa:** 003-01/25-01
**Urbroj:** 251-01-02-25-01 (Rev. 1.1)
**Datum:** 23.12.2025.

**PREDMET: Pravilnik o Jedinstvenom Sustavu Klasifikacije i Urudžbiranja Službenih Dokumenata i Projekata, Verzija 1.1**

---

#### **Članak 1: Svrha i Područje Primjene**

(1) Ovim Pravilnikom uspostavlja se jedinstven, nedvosmislen i strogo hijerarhijski sustav za označavanje, praćenje i arhiviranje svih projekata, dokumenata i poslovnih procesa unutar TEJL d.o.o.

(2) Svrha Pravilnika je osigurati apsolutnu sljedivost, sistemsku uređenost i birokratsku ispravnost cjelokupnog poslovanja. S pravilno formiranom Klasifikacijskom Oznakom i Urudžbenim Brojem, mora biti moguće trenutačno identificirati prirodu projekta i dokumenta.

(3) Odredbe ovog Pravilnika obvezujuće su za sve zaposlenike, suradnike i informacijske sustave Organizacije.

#### **Članak 2: Struktura Klasifikacijske Oznake (KLASE)**

(1) Klasifikacijska Oznaka (KLASA) je jedinstveni identifikator dodijeljen svakom projektu pri njegovom otvaranju. Ona definira prirodu i mjesto projekta unutar organizacije.

(2) Struktura KLASE je `GLAVNA.PODSKUPINA/GODINA-BROJ_DOSJEA`. Primjer: `310-10/25-001`.

*   **GLAVNA SKUPINA (3 znamenke):** Definira temeljnu prirodu i porijeklo projekta.
    *   `100`: **INTERNO POSLOVANJE**
    *   `300`: **POSLOVANJE S DOMAĆIM SUBJEKTIMA (REPUBLIKA HRVATSKA)**
    *   `400`: **POSLOVANJE S INOZEMNIM SUBJEKTIMA (EU I SVIJET)**
    *   `500`: **JAVNA NABAVA I POSLOVANJE S DRŽAVNIM INSTITUCIJAMA**

*   **PODSKUPINA (2 znamenke):** Preciznije definira vrstu usluge ili proizvoda unutar Glavne Skupine.
    *   *Unutar 100 (INTERNO):*
        *   `02`: Razvoj internih alata i sustava (npr. razvoj samog SIS-a)
    *   *Unutar 300 (DOMAĆI) i 400 (INOZEMNI):*
        *   `10`: **Digitalne Usluge - Standard** (Web stranice, CMS)
        *   `20`: **Digitalne Usluge - E-Commerce** (Web trgovine)
        *   `30`: **Digitalne Usluge - Aplikacije po Mjeri** (Custom softver)
        *   `70`: **Proizvodnja i Prodaja Hardvera** (Elektroničke jedinice)
    *   *Unutar 500 (JAVNA NABAVA):*
        *   `02`: Izvršenje ugovora

*   **GODINA (2 znamenke):** Zadnje dvije znamenke kalendarske godine u kojoj je projekt otvoren (npr. `25` za 2025.).

*   **BROJ DOSJEA (3 znamenke):** **Strogo sekvencijalni broj**, jedinstven unutar kombinacije `GLAVNA.PODSKUPINA/GODINA`. Prvi takav projekt u godini dobiva broj `001`, drugi `002`, itd. Sustav osigurava automatsko inkrementiranje.

#### **Članak 3: Struktura Urudžbenog Broja (URBROJ)**

(1) Urudžbeni Broj (URBROJ) je jedinstveni identifikator dodijeljen svakom **službenom izlaznom dokumentu** (ponuda, račun, dopis).

(2) Struktura URBROJA je `KLASA-TIP_DOK.VERZIJA-SEKVENCA`. Primjer: `310-10/25-001-PO.01-001`.

*   **KLASA:** **Puna i nepromijenjena** Klasifikacijska Oznaka projekta na koji se dokument odnosi.

*   **TIP DOKUMENTA (2 slova):**
    *   `PO`: Ponuda
    *   `PR`: Predračun
    *   `RA`: Račun
    *   `MM`: Memorandum
    *   `RN`: Radni Nalog

*   **VERZIJA (2 znamenke):** Broj revizije dokumenta. Prva verzija je uvijek `01`. Svaka izmjena (npr. promjena stavki na ponudi) stvara novu verziju (`02`, `03`...).

*   **SEKVENCA (3 znamenke):** **Jedinstveni, globalni brojač svih službenih dokumenata izdanih u tekućoj kalendarskoj godini**, neovisno o projektu ili klasi. Prvi dokument izdan u godini dobiva `001`, drugi `002`, itd.

#### **Članak 4: Procedura i Automatizacija (Rev. 1.1)**

(1) **Dodjela KLASE:**
    *   Prilikom unosa novog suradnika, operater je dužan označiti je li suradnik **domaći** ili **inozemni**.
    *   Prilikom kreiranja novog projekta, operater odabire suradnika i **tip usluge** (npr. "Digitalne Usluge - Standard").
    *   Samoupravni Informacijski Sustav (SIS) na temelju tih unosa **automatski i obvezujuće** određuje `GLAVNU SKUPINU` i `PODSKUPINU`.
    *   SIS zatim pretražuje bazu za najveći postojeći `BROJ_DOSJEA` unutar te **točne** kategorije (`GLAVNA.PODSKUPINA/GODINA`) i dodjeljuje sljedeći slobodan broj.
    *   Ručna izmjena KLASE nije dopuštena.

(2) **Dodjela URBROJA:**
    *   Prilikom generiranja novog dokumenta, SIS automatski:
        1.  **Povlači KLASU** pripadajućeg projekta.
        2.  **Postavlja TIP DOKUMENTA** na temelju odabira operatera (`Ponuda`, `Račun`...).
        3.  Postavlja **VERZIJU** na `01`.
        4.  Dohvaća posljednji korišteni globalni **SEKVENCA** brojač za tekuću godinu iz tablice `sequence_counters`, inkrementira ga za jedan i dodjeljuje novom dokumentu.
    *   Generiranje nove verzije postojećeg dokumenta zadržava sve dijelove URBROJA, ali inkrementira broj `VERZIJE`.

