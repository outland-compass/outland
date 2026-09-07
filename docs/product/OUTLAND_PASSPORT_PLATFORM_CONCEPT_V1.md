# OUTLAND Passport — Platform Concept V1

**Status:** Usvojeni proizvodni koncept  
**Datum:** 2026-09-06  
**Prvi pilot:** RAFTER

> **OUTLAND Passport je trajni fizički ključ koji OUTLAND-u govori ko je stigao, šta je već otkrio i šta u tom trenutku može da otključa.**

## 1. Status odluke

OUTLAND Passport je zajednički fizički i digitalni identitet gosta koji važi u svim OUTLAND svetovima.

Prvi pilot implementira se na svetu RAFTER, ali dugoročni koncept mora biti primenljiv na GREENHILL, NAVIGATOR, WANDERER, LOST VALLEY, ALIKI i buduće svetove.

Ovo je usvojeni proizvodni koncept. Nije odobrenje za izgradnju kompletnog PASSPORT modula niti za kreiranje svih mogućih budućih tabela.

## 2. Fizički Passport

Prva verzija nije štampana knjižica, već kvalitetna fizička kartica standardnog ID-1 formata sa sigurnim NFC čipom.

Kartica predstavlja:

1. trajni OUTLAND identitet osobe;
2. vremenski ograničen ključ za smeštaj;
3. interaktivni predmet u Mystery iskustvima;
4. credential za prijavljivanje na OUTLAND lokacijama;
5. vezu sa digitalnim Passport profilom;
6. credential koji se može koristiti u svim budućim svetovima.

Gost zadržava istu karticu i koristi je pri narednim OUTLAND posetama.

Passport je individualan i pripada osobi. Mystery sesija, rezervacija ili boravak mogu pripadati grupi ili posadi.

## 3. Fizički izgled

### Prednja strana

- tamna maslinastocrna mat podloga;
- reljefni OUTLAND simbol kompasa bez severne tačke;
- naziv `OUTLAND`;
- oznaka `PASSPORT`;
- jedinstveni broj formata `OP-000001`;
- diskretan NFC simbol.

### Zadnja strana

- `EVERY WORLD LEAVES A MARK`;
- diskretan QR kod;
- prostor za ime, nadimak ili potpis;
- minimalna informacija za vraćanje pronađene kartice.

Kartica ne sadrži fotografiju, datum rođenja, adresu niti druge nepotrebne lične podatke.

Materijal treba da bude kvalitetan mat PVC ili PETG, otporan na vodu i habanje.

Kartice se proizvode u većem tiražu sa jednom trajnom, generičkom grafikom. Na njima se ne štampaju konkretni svetovi, trenutni rangovi, datumi ili promenljivi Mystery sadržaji. Promenljive komponente su jedinstveni Passport broj, kriptografski credential i eventualni QR kod povezan sa Passport identitetom.

## 4. NFC tehnologija i bezbednost

Preporučeni credential za prototip je originalni `NXP MIFARE DESFire EV3 4K` sa AES autentikacijom.

Ne koristiti NTAG213 niti sistem zasnovan samo na javno čitljivom UID-u.

Kartica čuva bezbedan pseudonimni credential. OUTLAND OS ostaje primarni izvor istine za:

- identitet;
- dozvole;
- istoriju;
- Mystery stanje;
- artefakte;
- achievements;
- World statuse.

Kompletan napredak ne čuva se prvenstveno na kartici. Jedan čip može podržati logički odvojene funkcije, ali softverski domeni i njihova odgovornost ostaju odvojeni.

Izgubljena kartica može biti opozvana i zamenjena bez gubitka profila i trajnog napretka.

„Trenutna deaktivacija” važi za povezane terminale. Offline terminal saznaje za opoziv prilikom sledeće sinhronizacije, zbog čega lokalno keširane dozvole moraju biti vremenski ograničene.

QR kod ne sme sadržati kriptografski credential, trajni login token niti drugi bearer secret. Može sadržati javni Passport identifikator ili bezbedan URL za otvaranje ili oporavak profila.

Nezavisnost od proizvođača brave postiže se kroz OUTLAND terminal/kontroler i standardizovan izlaz prema bravi. Sistem ne sme biti čvrsto vezan za jedan model brave.

## 5. Granice odgovornosti

- **PASSPORT** poseduje trajni identitet, credential i odabrane trajne posledice putovanja.
- **BOOKING** poseduje rezervaciju i istinu o periodu boravka.
- **UNIVERSE ENGINE** poseduje Mystery pravila, sesije i napredovanje priče.
- **SENSE** poseduje terminale, NFC interakcije, uređaje, telemetriju i fizičke komande.

Primer toka:

**BOOKING potvrđuje važeći boravak**  
→ **Access Grant dozvoljava ulaz**  
→ **SENSE autentifikuje Passport**  
→ **UNIVERSE ENGINE proverava i menja Mystery stanje**  
→ **SENSE izvršava bezbednu fizičku reakciju**  
→ **PASSPORT pamti odabranu trajnu posledicu**

PASSPORT ne poseduje rezervacionu istinu, Mystery pravila niti stanje uređaja.

## 6. Glavne funkcije

Passport dugoročno može podržati:

- digitalni profil;
- posećene i završene svetove;
- Mystery odluke;
- pronađene artefakte;
- achievements i statuse;
- aktivne i istorijske pristupe;
- buduće ekspedicije;
- membership ili loyalty funkcije.

Ovo je produktni pravac, ne početni implementation scope.

## 7. Pristup smeštaju

Tokom aktivnog boravka isti Passport privremeno otključava odgovarajući smeštaj. Pristup se aktivira pri check-inu i prestaje pri check-outu, dok kartica i trajni profil ostaju gostu.

Svaki objekat mora imati:

- rezervni mehanički ili drugi bezbedan administrativni pristup;
- administrativno otključavanje;
- bezbedan izlaz nezavisan od NFC sistema;
- vremenski ograničen lokalni pristup tokom prekida interneta.

Osnovna funkcija smeštaja ne sme zavisiti od Mystery logike.

## 8. Mystery interakcije

Passport se može koristiti na fizičkim OUTLAND terminalima kako bi:

- potvrdio dolazak;
- registrovao pronađeni trag;
- pokrenuo audio, svetlo ili projekciju;
- otvorio bezbednu kutiju, fioku ili orman;
- promenio Mystery fazu;
- dodelio artefakt ili achievement;
- aktivirao sadržaj zavisan od ranijih iskustava.

Terminal je spoj NFC čitača, lokalnog kontrolera i jednog ili više bezbednih fizičkih izlaza.

## 9. RAFTER pilot

RAFTER je prvi konkretan svet za proveru koncepta.

### Terminal 1 — ulaz

- autentifikuje Passport;
- proverava vremenski ograničenu lokalnu dozvolu;
- otključava testnu ili stvarnu bravu;
- beleži dolazak;
- može aktivirati početak Mystery sesije;
- nastavlja da radi sa ograničenim, lokalno keširanim pristupom tokom prekida interneta.

### Terminal 2 — Mystery tačka

- autentifikuje isti Passport;
- proverava trenutno stanje Mystery sesije;
- dozvoljava ili odbija sledeći korak;
- aktivira svetlo i audio-poruku;
- otključava testnu fioku ili Mystery orman;
- odbija akciju ako prethodni uslov nije ispunjen.

Prvi trajni Passport achievement je:

`RIVER_KEEPER` — korisnički naziv: `ČUVAR REKE`

Na check-outu prestaje pristup RAFTER-u, ali achievement ostaje trajno povezan sa osobom.

Kompletan kasniji RAFTER tok može obuhvatiti ulaz, četiri do pet Mystery checkpointa i završni terminal Kartografovog ormana, ali taj obim nije deo prvog tehničkog prototipa.

## 10. Minimalni prototip — podaci

Za prvi prototip projektovati samo minimum potreban za stvarni tok:

- Passport;
- osobu kojoj Passport pripada;
- credential;
- aktivaciju, opoziv i zamenu credentiala;
- vremenski ograničenu RAFTER pristupnu dozvolu;
- jednu Mystery sesiju;
- nekoliko konkretnih Mystery koraka;
- jedan trajni achievement;
- dva terminala;
- evidenciju terminalskih događaja i sinhronizacije.

Ne praviti unapred poseban model ili tabelu za svaki budući pojam.

Sledeći pojmovi predstavljaju konceptualni budući model, a ne trenutni zahtev za tabelama:

- World;
- Location;
- Reservation;
- Access Grant;
- Check-in Event;
- Mystery;
- Mystery Step;
- Artifact;
- Achievement;
- World Status;
- Device;
- Device Action;
- Revocation and Replacement Record.

Njihovo konačno vlasništvo, struktura i persistence model izvode se iz RAFTER prototipa i postojećih granica domena.

## 11. Terminalski događaj

Za prototip terminalski događaj treba da omogući beleženje:

- pseudonimnog Passport identifikatora;
- terminala;
- Worlda i lokacije;
- vremena;
- povezane Mystery sesije kada postoji;
- rezultata autentikacije;
- dozvoljene ili odbijene akcije;
- izvršene fizičke reakcije;
- statusa lokalne i serverske sinhronizacije.

Čuvati samo podatke potrebne za rad, dijagnostiku, bezbednost i validaciju prototipa.

## 12. PASS/FAIL

Prototip je uspešan samo ako:

1. ista DESFire kartica otključava ulaz tokom važeće dozvole;
2. ulaz radi tokom kontrolisanog prekida interneta;
3. Mystery terminal odbija nedozvoljen ili pogrešan redosled;
4. ispravan korak aktivira svetlo, audio i testni aktuator;
5. achievement `RIVER_KEEPER` ostaje nakon check-outa;
6. kartica može biti opozvana i zamenjena bez gubitka profila;
7. terminali naknadno sinhronizuju offline događaje;
8. kvar sistema degradira iskustvo na bezbedan, normalan boravak.

## 13. Nije deo prvog prototipa

Ne graditi sada:

- kompletan PASSPORT portal;
- loyalty ili membership sistem;
- Field Journal;
- više svetova;
- generalizovani game engine;
- generalizovani IoT management sistem;
- kompletnu BOOKING platformu;
- napredni content editor;
- univerzalni rules engine;
- veliki skup budućih tabela;
- integracije sa više proizvođača brava.

## 14. Kasniji Field Journal

Štampana knjižica se ne uvodi u prvoj fazi.

Kasnije može postojati opcioni premium `OUTLAND Field Journal` za:

- fizičke pečate;
- mape;
- beleške;
- artefakte;
- kolekcionarstvo.

Može imati džep za Passport karticu, ali ne predstavlja ključ i nije tehnički obavezan.

## 15. Radne procene troškova

Sledeće procene nisu potvrđene ponude dobavljača:

- 100 DESFire EV3 kartica: približno 800 EUR;
- 500 kartica: približno 2.100 EUR;
- 1.000 kartica: približno 3.550 EUR;
- prototip sa dva terminala: približno 3.000–5.000 EUR;
- kompletan RAFTER pilot: približno 7.000–9.000 EUR;
- profesionalna izvedba sa rezervnom opremom: približno 10.000–15.000 EUR.

## 16. Sledeći korak

Sledeći dokument, pre bilo kakve šeme ili implementacije, jeste `RAFTER Passport Prototype V0.1`: konkretan tok dva terminala, izbor prototipskog hardvera, minimum persistent podataka i izvršivi PASS/FAIL testovi.

Tek rezultati tog prototipa mogu opravdati proširenje PASSPORT, SENSE, Universe Engine ili BOOKING modela.


## 17. RAFTER ulazni portal — kanonska odluka

Ulazni terminal RAFTER-a nalazi se na ručno otvaranim vratima između otvorenog Front Deck-a i zatvorenog River Room-a. Nije na krmi niti između servisne zone i Inner Room-a.

Gost prislanja DESFire EV3 Passport na diskretno označeno mesto. Skriveni čitač i lokalni OUTLAND terminal proveravaju vremenski ograničenu dozvolu i kratko oslobađaju skriveni fail-secure električni prihvatnik; gost zatim otvara običnu kvaku rukom.

Izlazak iznutra je uvek mehanički i nezavisan od Passporta, NFC-a, interneta, napajanja, Mystery stanja i OUTLAND OS-a. Sistem mora podržati administrativno otključavanje, vremenski ograničen offline pristup, senzor zatvorenosti vrata i rezervni mehanički pristup operatora.

Prototipska referenca prihvatnika je `ASSA ABLOY effeff 118, 10–24 V AC/DC, fail-secure`; konačna čeona ploča/varijanta i maska ispred antene ostaju `TO VERIFY`. Automatska/motorizovana vrata, generička hotelska smart-brava, vidljivi keypad/ekran i NFC kutija koja izdaje fizički ključ nisu primarno RAFTER V1 rešenje.
