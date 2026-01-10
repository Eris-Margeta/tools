# AMAZING MAC CLEANER ilitiga fantastični Mac čistač [DEPRECATED]

Sveobuhvatna skripta za čišćenje, održavanje i konfiguraciju macOS-a.

Ova skripta je dizajnirana da oslobodi značajnu količinu prostora na disku i optimizira vaš macOS sustav automatiziranim čišćenjem raznih cache datoteka, logova, nepotrebnih sistemskih datoteka i još mnogo toga. Najvažnije od svega - briše Apple bolesti s računala poput Spotlighta i skrivenih snapshota koji tjeraju korisnike na cloud upgrade

## Glavne Značajke

Skripta nudi modularni pristup čišćenju, omogućujući vam da odaberete koje zadatke želite izvršiti:

-   **Čišćenje Cachea**: Briše korisnički i sistemski cache (`~/Library/Caches`).
-   **Čišćenje Logova**: Uklanja nagomilane log datoteke.
-   **Cache Preglednika**: Čisti cache za Safari, Chrome i Firefox.
-   **Pražnjenje Smeća**: Sigurno prazni smeće za sve korisnike.
-   **Uklanjanje Instalacijskih Datoteka**: Briše preostale macOS instalacijske datoteke.
-   **Čišćenje Razvojnih Alata**: Uklanja cache za Homebrew, Docker i Xcode, oslobađajući gigabajte prostora.
-   **Optimizacija Binarnih Datoteka**: Uklanja nepotrebne arhitekture iz "Universal Binaries", ostavljajući samo onu koja je potrebna za vaš Mac (Intel ili Apple Silicon).
-   **Uklanjanje Skrivenih APFS Snapshota**: Jedna od najmoćnijih značajki. macOS u pozadini automatski stvara lokalne APFS snapshote diska, koji mogu zauzimati ogromnu količinu prostora bez znanja korisnika.
    -   Ova opcija sigurno **uklanja te skrivene lokalne snapshote**.
    -   **VAŽNO**: Ovo **ne utječe** na vaše standardne Time Machine sigurnosne kopije koje se nalaze na vanjskim diskovima. Vaši Time Machine backupi su sigurni.

## ⚠️ Upozorenje: Uklanjanje Spotlight Indexa

Ova skripta nudi opciju **potpunog onemogućavanja i brisanja Spotlight indexa**. Ovo može osloboditi značajan prostor i smanjiti pozadinsku aktivnost sustava, ali ima veliku posljedicu:

-   **Spotlight pretraga prestat će raditi.**

Ovu opciju trebali bi koristiti **isključivo napredni korisnici** koji se ne oslanjaju na nativnu Spotlight pretragu i umjesto toga koriste alternativne launchere.

Ako ste jedan od tih korisnika, preporučujemo [**Sol Launcher**](https://sol.ospfranco.com/), modernu i brzu alternativu za Spotlight i Raycast.

## Kako Koristiti

1.  **Preuzmite skriptu**:
    ```bash
    git clone https://github.com/Eris-Margeta/amazing-mac-cleaner.git
    cd amazing-mac-cleaner
    ```
2.  **Učinite je izvršnom**:
    ```bash
    chmod +x mac-cleaner.sh
    ```
3.  **Pokrenite skriptu**:
    Skripta zahtijeva administratorske ovlasti za pristup sistemskim datotekama.
    ```bash
    sudo ./mac-cleaner.sh
    ```
4.  **Pratite upute**:
    Skripta će vas voditi kroz interaktivni izbornik gdje možete odabrati koje akcije želite poduzeti.

## Odricanje od odgovornosti

Koristite ovu skriptu na vlastitu odgovornost. Iako je temeljito testirana, autor ne preuzima odgovornost za eventualni gubitak podataka. Preporučuje se da napravite sigurnosnu kopiju važnih podataka prije pokretanja.
