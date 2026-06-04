# Architecture — Système de réservation Chalet Mont Rose

Document de conception et feuille de route pour le module de réservation client + back-office.

## 1. Objectif

Permettre à un client de :
1. Consulter un **calendrier épuré** affichant la disponibilité et le **prix par jour**.
2. Sélectionner une période **du samedi au samedi** et voir le **prix total**.
3. Envoyer une **demande de réservation** (email de notification au propriétaire).

Permettre au propriétaire (admin) de :
4. Renseigner les **prix par semaine** (samedi → samedi).
5. **Valider / refuser / modifier** une demande.
6. À la validation : **un seul email** au client = facture des **arrhes** (virement) + **contrat à signer** (Dropbox Sign) + **demande de caution** (Swikly).
7. Bénéficier de l'**envoi automatique du solde à J-10** (CGU + livret du chalet, admin en copie) et garder un **journal des emails** (avec pièces jointes) en admin.
8. Consulter la **liste des réservations** avec factures, contrats et cautions.
9. *(Phase 2)* transmettre automatiquement les factures vers **Dext**.

## 2. Choix techniques retenus

| Domaine | Choix | Détail |
|---|---|---|
| Framework | Rails 8.1 / Hotwire | déjà en place (Turbo + Stimulus, importmap, Propshaft) |
| Style | Tailwind + FlyonUI | réutiliser le design « stone / serif » existant |
| Jobs async | Solid Queue | déjà présent — emails, PDF, appels API, récurrents |
| Autorisations | Pundit | déjà présent — policies admin |
| Paiement arrhes | **Virement manuel** | RIB sur la facture, pointage manuel dans l'admin |
| Signature contrat | **Dropbox Sign API** | gem `dropbox-sign`, signature **embarquée** (lien sur notre site) + webhook |
| Caution | **Swikly API** | caution dématérialisée (empreinte/pré-autorisation), lien transmis au client |
| Emails | **SMTP Gmail** | ActionMailer + mot de passe d'application |
| PDF factures | **Prawn** | pur Ruby, aucune dépendance système (Docker-friendly) |
| Compta (phase 2) | **Dext** | envoi de la facture PDF vers l'inbox Dext |
| Monnaie | entiers `*_cents` | helper d'affichage `€` (option : `money-rails`) |

### Gems à ajouter au `Gemfile`

```ruby
gem "prawn"            # génération PDF facture
gem "prawn-table"      # tableaux dans le PDF
gem "dropbox-sign"     # signature électronique (ex hellosign-ruby-sdk)
gem "faraday"          # client HTTP pour l'API Swikly (pas de gem officielle)
# optionnel
gem "money-rails"      # manipulation/formatage des montants
```

## 3. Modèle de données

```
User (existant)
 ├─ admin:boolean (existant)
 └─ has_many :bookings (optionnel, si client connecté)

WeeklyRate                         # tarif d'une semaine samedi→samedi
 ├─ week_start:date (un samedi, indexé, unique)
 ├─ price_cents:integer
 ├─ min_weeks:integer  default 1
 └─ note:string

Booking                            # demande de réservation
 ├─ check_in:date (samedi)
 ├─ check_out:date (samedi)
 ├─ guests_count:integer
 ├─ first_name / last_name / email / phone
 ├─ message:text
 ├─ status:integer (enum)          # pending/confirmed/rejected/cancelled
 ├─ total_price_cents:integer
 ├─ deposit_cents:integer          # arrhes
 ├─ token:string (unique, accès client sans login)
 ├─ user_id:bigint (nullable)
 ├─ has_one :invoice
 ├─ has_one :contract
 └─ has_one :caution

Invoice                            # facture
 ├─ booking_id
 ├─ number:string (unique, ex CMR-2026-0001)
 ├─ issued_on:date
 ├─ total_cents / deposit_cents / balance_cents
 ├─ deposit_status:integer (enum)  # awaiting/received       (arrhes)
 ├─ deposit_received_on:date
 ├─ balance_status:integer (enum)  # awaiting/received       (solde)
 ├─ balance_received_on:date
 ├─ balance_reminder_sent_at:datetime  # mail J-10 (anti-doublon)
 ├─ forwarded_to_dext_at:datetime      # phase 2
 └─ pdf (Active Storage attachment)

Contract                           # contrat
 ├─ booking_id
 ├─ provider_request_id:string     # signature_request_id Dropbox Sign
 ├─ status:integer (enum)          # draft/sent/signed/declined
 ├─ sent_at / signed_at:datetime
 └─ signed_pdf (Active Storage attachment)

Caution                            # caution dématérialisée (Swikly)
 ├─ booking_id
 ├─ provider_request_id:string     # id Swik (Swikly)
 ├─ amount_cents:integer
 ├─ status:integer (enum)          # pending/accepted/released/captured/declined
 ├─ deposit_url:string             # lien à transmettre au client
 └─ requested_at / accepted_at:datetime

EmailLog                           # journal des emails envoyés (admin)
 ├─ booking_id (nullable)
 ├─ mailer:string / action:string
 ├─ to:string / cc:string / subject:string
 ├─ sent_at:datetime
 └─ attachments (Active Storage, has_many_attached)  # contrat, facture…

Document                           # documents statiques gérés en admin
 ├─ kind:integer (enum)            # cgu / livret
 ├─ title:string
 └─ file (Active Storage attachment)
```

### Notes de modélisation

- **Disponibilité** : une `Booking` au statut `confirmed` bloque ses semaines. Le calendrier marque ces semaines indisponibles.
- **Tarif par jour** affiché = `WeeklyRate.price_cents / 7` (affichage indicatif). Le **prix de la période** = somme des `WeeklyRate` des semaines couvertes.
- Une semaine **sans `WeeklyRate`** = non réservable (grisée).
- `token` (ex `SecureRandom.urlsafe_base64`) : le client suit sa réservation via `/reservations/:token` sans compte.
- Montants stockés en **centimes** pour éviter les flottants.
- **Journal des emails** : un *delivery observer* ActionMailer enregistre chaque email sortant dans `EmailLog` (destinataires, CC, sujet, pièces jointes) → consultable en admin.
- **CGU + livret** : `Document` gérés en admin (upload), joints à l'email J-10.
- **Caution** : gérée par **Swikly** (empreinte/pré-autorisation, pas d'encaissement immédiat) ; statut suivi via l'API + webhook Swikly.

## 4. Tarification (samedi → samedi)

Service de calcul centralisé :

```
app/services/pricing.rb
  Pricing.nightly_for(date)        → prix indicatif/nuit de la semaine contenant `date`
  Pricing.weeks_between(in, out)   → liste des week_start (samedis) couverts
  Pricing.quote(check_in, check_out)
        → { bookable:, total_cents:, deposit_cents:, weeks: [...] }
```

Règles :
- `check_in` et `check_out` **doivent être des samedis** (validation modèle + UI).
- Toutes les semaines de la période doivent avoir un `WeeklyRate`, sinon `bookable: false`.
- `deposit_cents = (total_cents * DEPOSIT_RATE).round` (ex. `DEPOSIT_RATE = 0.30`).

Admin — saisie des prix :
- CRUD `WeeklyRate` semaine par semaine.
- **Éditeur en lot** : appliquer un prix sur une plage de dates (génère/maj les `WeeklyRate` pour chaque samedi de la plage) → permet de définir une « saison » rapidement.

## 5. Calendrier (client)

- Rendu **server-side par mois** dans un **Turbo Frame** (`calendar_month`), navigation mois précédent/suivant sans rechargement.
- **Stimulus `calendar_controller`** pour la sélection (clic arrivée → clic départ), surlignage de la plage, calcul/affichage du total via la quote.
- Chaque cellule jour affiche : prix/nuit, état (disponible / réservé / non tarifé).
- Contrainte visuelle : seules les arrivées/départs **samedi** sont sélectionnables.
- Deux points d'entrée partagent le même `calendar_controller` :
  - **Page `/calendrier`** : calendrier + sidebar de devis, bouton « Demander » qui ouvre la modale.
  - **Home ([home.html.erb](app/views/pages/home.html.erb))** : le bouton **Réserver** ouvre la modale de demande ; un **bouton unique « Dates »** ouvre le **calendrier en surimpression** (au-dessus de la modale) pour choisir l'intervalle **samedi → samedi**. La sélection calcule le devis (`/calendrier/quote`), remplit les champs cachés `check_in`/`check_out` + le récap, et n'active le bouton d'envoi qu'une fois les dates valides. Soumission → `reservations#create`.

Design : réutiliser la palette `stone`, coins arrondis `rounded-2xl`, typographie `font-serif` pour les titres — cohérent avec l'existant.

## 6. Routes

```ruby
# Public
get  "calendrier",        to: "bookings#calendar"     # ou section sur la home
resources :reservations, only: [:new, :create, :show], param: :token do
  member { get :contract }        # page de signature embarquée Dropbox Sign
end

# Admin (namespace + Pundit)
namespace :admin do
  root to: "dashboard#index"                           # existant
  resources :weekly_rates                               # tarifs + éditeur en lot
  resources :bookings, only: [:index, :show, :edit, :update] do
    member do
      patch :confirm
      patch :reject
    end
  end
  resources :invoices, only: [:index, :show] do
    member { patch :mark_deposit_received; patch :mark_balance_received }
  end
  resources :contracts, only: [:index, :show] do
    member { post :resend }
  end
  resources :cautions, only: [:index, :show] do
    member { post :resend }
  end
  resources :documents                                  # CGU + livret (upload)
  resources :email_logs, only: [:index, :show]          # journal des emails
end

# Webhooks
post "webhooks/dropbox_sign", to: "webhooks/dropbox_sign#create"
post "webhooks/swikly",       to: "webhooks/swikly#create"
```

## 7. Parcours & flux

### Flux A — Demande client
1. Client ouvre le calendrier → sélectionne samedi→samedi.
2. `Pricing.quote` calcule le total → modale pré-remplie.
3. `POST /reservations` crée une `Booking` `status: pending` + `token`.
4. `BookingMailer.new_request_to_owner` → **email vers ton adresse perso** (`MAILER_OWNER_EMAIL`).
5. (option) `BookingMailer.acknowledgement_to_client` → accusé de réception.
6. Page `/reservations/:token` : « demande en attente de validation ».

### Flux B — Validation admin → **email unique groupé**
1. Admin voit les demandes `pending` dans `admin/bookings`.
2. Actions : **Confirmer** / **Refuser** / **Modifier** (dates, prix, nb voyageurs).
3. Sur **Confirmer** (`PATCH confirm`), en arrière-plan :
   - `status: confirmed` (bloque les semaines).
   - `GenerateInvoiceJob` → `Invoice` + PDF Prawn (facture **arrhes** + **RIB**).
   - `SendContractJob` → Dropbox Sign **signature embarquée** → lien hébergé sur notre site (`/reservations/:token/contract`).
   - `CreateCautionJob` → Swikly → `deposit_url` (lien caution).
4. **Un seul email** `BookingMailer.confirmation` au client contenant :
   - la **facture des arrhes** (PDF) + instructions de virement (RIB) ;
   - le **lien de signature du contrat** ;
   - la **demande de caution Swikly** (lien).
5. Sur **Refuser** → `status: rejected` + `BookingMailer.rejected`.

> ⚠️ Pour tout regrouper dans **un seul** email, on utilise la **signature embarquée** Dropbox Sign (et non l'email automatique de Dropbox Sign) : le lien pointe vers une page de notre site qui affiche l'iframe de signature. Idem, le lien Swikly est inséré dans notre email.

### Flux C — Arrhes (virement manuel)
1. Le client vire les **arrhes** (RIB sur la facture).
2. Admin pointe **« Arrhes reçues »** (`mark_deposit_received`) → `invoice.deposit_status: received`.
3. Le solde est traité au Flux F (rappel J-10) puis pointé via `mark_balance_received`.

### Flux D — Signature contrat (Dropbox Sign, embarquée)
1. `SendContractJob` crée une **signature embarquée** depuis le template.
2. Le client ouvre `/reservations/:token/contract` (lien du mail) et signe dans l'iframe.
3. **Webhook** `signature_request_all_signed` → `Webhooks::DropboxSignController` :
   - vérifie l'event, met `contract.status: signed`, `signed_at`.
   - télécharge le **PDF signé** (`signature_request_files`) → `contract.signed_pdf`.
   - répond `Hello API Event Received` (exigé par Dropbox Sign).

### Flux E — Caution (Swikly)
1. `CreateCautionJob` crée la demande de caution via l'API Swikly → `deposit_url`.
2. Le lien est inclus dans l'email de confirmation (Flux B).
3. Le client dépose sa caution (empreinte/pré-autorisation, **pas de débit**).
4. **Webhook** Swikly → `Webhooks::SwiklyController` met `caution.status` à jour (`accepted`, etc.).
5. En fin de séjour : caution **libérée** ou **capturée** (action admin / Swikly).

### Flux F — Rappel du solde (J-10, automatique)
- Tâche **récurrente quotidienne** `BalanceReminderJob` (Solid Queue recurring) : sélectionne les réservations `confirmed` dont `check_in == aujourd'hui + BALANCE_REMINDER_DAYS` (10 j) et dont le **solde** n'est pas réglé.
- Envoie `BookingMailer.balance_reminder` au client, **admin en copie (CC)** :
  - demande de **règlement du solde** (RIB) ;
  - rappel des **CGU** du chalet (`Document` cgu) ;
  - **livret du chalet** + recommandations (`Document` livret) ;
  - **pièces jointes** : facture + contrat signé.
- `invoice.balance_reminder_sent_at` horodaté (anti-doublon) ; email tracé dans `EmailLog`.

### Flux G — Vue d'ensemble admin
- `admin/bookings#index` : tableau réservations (statut, dates, client, total) avec liens **facture PDF** + **contrat signé** + **caution** + état arrhes/solde.

### Flux H — Export Dext *(phase 2)*
- `ForwardInvoiceToDextJob` : envoie la facture PDF en pièce jointe vers l'**inbox Dext** (`DEXT_INBOX_EMAIL`) après réception des arrhes (ou à l'émission, selon besoin), puis `invoice.forwarded_to_dext_at`.

## 8. Mailers

```
BookingMailer
  new_request_to_owner(booking)     # → toi (nouvelle demande)
  acknowledgement_to_client(booking)# accusé réception (option)
  confirmation(booking)             # EMAIL GROUPÉ : facture arrhes + RIB
                                    #   + lien signature contrat + lien caution Swikly
  rejected(booking)                 # refus
  balance_reminder(booking)         # J-10 : solde + CGU + livret, CC admin,
                                    #   pièces jointes facture + contrat signé

AccountingMailer                    # phase 2
  forward_invoice(invoice)          # → inbox Dext

# Journalisation : un delivery observer ActionMailer enregistre chaque envoi dans EmailLog.
```

Tous les envois en `deliver_later` (Solid Queue).

## 9. Jobs (Solid Queue)

```
GenerateInvoiceJob        # crée Invoice + PDF Prawn
SendContractJob           # Dropbox Sign — signature embarquée
CreateCautionJob          # Swikly — crée la demande de caution
SendConfirmationEmailJob  # email groupé (une fois invoice + contrat + caution prêts)
DownloadSignedContractJob # déclenché par le webhook Dropbox Sign
BalanceReminderJob        # récurrent quotidien (J-10) — config/recurring.yml
ForwardInvoiceToDextJob   # phase 2
```

> `BalanceReminderJob` est déclaré dans `config/recurring.yml` (Solid Queue) en tâche quotidienne.

## 10. PDF facture (Prawn)

Service `app/services/invoice_pdf.rb` :
- En-tête : « Chalet Mont Rose » + coordonnées.
- Client, n° facture, date.
- Lignes : période (samedi→samedi), nb semaines, total.
- **Arrhes à régler** (montant + échéance) + **RIB (IBAN/BIC/titulaire)**.
- Mentions légales (arrhes — voir §13).
- Attaché à `invoice.pdf` (Active Storage, service `:local`, déjà configuré).

## 11. Autorisations (Pundit)

- `BookingPolicy`, `WeeklyRatePolicy`, `InvoicePolicy`, `ContractPolicy`, `CautionPolicy`, `DocumentPolicy`, `EmailLogPolicy` : management **réservé `admin?`**.
- Accès client à **sa** réservation via `token` (pas de login requis) — contrôleur public dédié, pas de Pundit.
- `Webhooks::*Controller` : `skip` CSRF + vérification de l'authenticité de l'event (clé/hash fournisseur).

## 12. Variables d'environnement (`.env`)

```bash
# SMTP Gmail
GMAIL_SMTP_USERNAME=...
GMAIL_SMTP_APP_PASSWORD=...        # mot de passe d'application Google (2FA requise)
MAILER_FROM="Chalet Mont Rose <...@gmail.com>"
MAILER_OWNER_EMAIL=...             # ton adresse perso (notifs + CC solde)

# Dropbox Sign (signature embarquée)
DROPBOX_SIGN_API_KEY=...
DROPBOX_SIGN_CLIENT_ID=...         # API App (signature embarquée)
DROPBOX_SIGN_TEMPLATE_ID=...       # template de contrat créé dans le dashboard
DROPBOX_SIGN_TEST_MODE=true        # tant qu'on n'est pas en prod

# Swikly (caution)
SWIKLY_API_KEY=...
SWIKLY_API_SECRET=...
SWIKLY_TEST_MODE=true
CAUTION_AMOUNT=...                 # montant de la caution (en €)

# Réservation / facturation
DEPOSIT_RATE=0.30                  # part des arrhes
BALANCE_REMINDER_DAYS=10           # rappel du solde (jours avant l'arrivée)
COMPANY_IBAN=...
COMPANY_BIC=...
COMPANY_ACCOUNT_HOLDER=...

# Phase 2 — Dext
DEXT_INBOX_EMAIL=...@dext.cc
```

> ⚠️ Gmail SMTP : activer la **2FA** et générer un **mot de passe d'application**. Limite ~500 mails/jour (large pour ce volume). Surveiller la délivrabilité (SPF/DKIM limités sur Gmail perso).

## 13. Points juridiques à valider

- **Arrhes** (terme retenu, art. 1590 Code civil) : chaque partie peut se dédire — le client perd les arrhes, le propriétaire en rembourse le double. Wording à figer sur la facture et le contrat.
- **Caution** : la caution Swikly (empreinte/pré-autorisation) est distincte des arrhes ; préciser son montant et ses conditions de libération/capture dans les CGU.
- **Contrat de location saisonnière** : mentions obligatoires (descriptif, prix, durée, état des lieux, caution). Faire valider le template Dropbox Sign.
- **RGPD** : données clients (mail, tél) — conservation et finalité ; CGU/mentions à prévoir.

## 14. Feuille de route par étapes

### Phase 0 — Fondations ✅
- [x] Ajouter les gems (`prawn`, `prawn-table`, `dropbox-sign`, `faraday`).
- [x] Configurer **ActionMailer SMTP Gmail** (dev + prod) via ENV.
- [x] Helper d'affichage des montants (`cents → €`) — `MoneyHelper#money`.

### Phase 1 — Tarification + calendrier ✅
- [x] Migration + modèle `WeeklyRate` (+ validation « samedi », accessor euros↔centimes).
- [x] `admin/weekly_rates` : CRUD + **éditeur en lot** (plage de dates) — gardé par `Admin::BaseController` + Pundit.
- [x] Service `Pricing` (quote, weeks_between, nightly_cents_for).
- [x] Calendrier public (Turbo Frame mois + `calendar_controller` Stimulus) + endpoint JSON `/calendrier/quote`.

### Phase 2 — Demande de réservation ✅
- [x] Migration + modèle `Booking` (enum statut, token, validations samedi).
- [x] Sélection calendrier → modale pré-remplie → `reservations#create`.
- [x] `BookingMailer.new_request_to_owner` (+ accusé client option).
- [x] Page publique `/reservations/:token` (suivi).

### Phase 3 — Back-office validation ✅
- [x] `admin/bookings` : index + show + edit/update (modifier dates/prix).
- [x] Actions `confirm` / `reject` + blocage des semaines confirmées.
- [x] Policies Pundit.

### Phase 4 — Facturation (arrhes / virement) ✅
- [x] Migration + modèle `Invoice` (numérotation, statuts arrhes/solde).
- [x] `GenerateInvoiceJob` + `InvoicePdf` (Prawn, RIB + arrhes).
- [x] Admin : `mark_deposit_received` / `mark_balance_received`.

### Phase 5 — Contrat (embarqué) + caution + email groupé
- [ ] Template de contrat dans Dropbox Sign + API App (embarqué).
- [ ] Migration + modèle `Contract` ; page `/reservations/:token/contract` (iframe).
- [ ] `SendContractJob` (embarqué) + `Webhooks::DropboxSignController` + `DownloadSignedContractJob`.
- [ ] Migration + modèle `Caution` ; `CreateCautionJob` (Swikly) + `Webhooks::SwiklyController`.
- [ ] `BookingMailer.confirmation` = **email unique** : facture arrhes + lien signature + lien caution.

### Phase 6 — Rappel du solde (J-10) + journal des emails
- [ ] `Document` (CGU + livret) gérés en admin (upload).
- [ ] `BalanceReminderJob` récurrent (`config/recurring.yml`) : solde + CGU + livret, **CC admin**, PJ facture + contrat.
- [ ] `EmailLog` + delivery observer ActionMailer ; admin `email_logs` (liste + pièces jointes).

### Phase 7 — Vue d'ensemble admin
- [ ] Tableau réservations : statut arrhes/solde/caution + liens facture, contrat signé, caution.
- [ ] Filtres (statut, période).

### Phase 8 — Export comptable Dext *(plus tard)*
- [ ] `ForwardInvoiceToDextJob` → `AccountingMailer.forward_invoice` vers `DEXT_INBOX_EMAIL`.
- [ ] Marqueur `forwarded_to_dext_at` + relance si échec.

### Phase 9 — Alertes Telegram pour la taxe de séjour *(à venir)*
- [ ] Bot Telegram (token + chat ID admin via ENV) — `TelegramNotifier` service léger (HTTP via Faraday).
- [ ] Job récurrent quotidien `TouristTaxReminderJob` (Solid Queue, `config/recurring.yml`) :
  - **1er → 15 octobre** : rappel de payer la taxe de séjour de la période **mai – septembre** (période d'été close), tant que le `TouristTaxPeriod{summer, année courante}` n'est pas marqué `paid`.
  - **1er → 15 mai** : rappel de payer la période **octobre – avril** (période d'hiver close), tant que le `TouristTaxPeriod{winter, année précédente}` n'est pas marqué `paid`.
- [ ] Message Telegram : libellé de la période, montant cumulé (depuis `TouristTaxPeriod#tax_total_cents`), lien vers `/admin/booking_setting`.
- [ ] Une notification par jour max pendant la fenêtre — horodatée pour éviter les doublons.

## 15. Tests (Minitest)

- **Unitaires** : `Pricing` (quotes, semaines, non-tarifé), validations `Booking` (samedi, chevauchement), numérotation `Invoice`.
- **Mailers** : contenu + destinataires (`new_request_to_owner` → owner ; `balance_reminder` → client + CC admin + PJ).
- **Système (Capybara)** : sélection calendrier → demande ; parcours admin confirmer → email groupé.
- **Webhooks** : `signed` → contrat signé + PDF stocké ; Swikly → caution `accepted` (stubs API).
- **Jobs** : enchaînement à la confirmation (invoice + contrat + caution) ; `BalanceReminderJob` (sélection J-10, anti-doublon).
- **EmailLog** : observer enregistre chaque envoi avec pièces jointes.

## 16. Schéma de séquence (validation)

```
Client            App                  Admin       Dropbox Sign   Swikly    Toi (email)
  │  demande ──▶  │                                                            │
  │              │ Booking(pending) ──────────────────────────────────────▶  │ notif
  │              │                      │ voit la demande                      │
  │              │ ◀── confirm ─────────│                                      │
  │              │ Invoice + PDF (RIB)                                         │
  │              │ contrat (embarqué) ─────────────▶ │                         │
  │              │ caution ──────────────────────────────────────▶ │          │
  │ ◀ EMAIL UNIQUE : facture + lien signature + lien caution ──────│          │
  │ ─ signe ─────────────────────────▶ │                           │          │
  │ ─ dépose caution ─────────────────────────────────────────────▶ │        │
  │              │ ◀ webhook signed ── │                            │          │
  │              │ ◀ webhook caution ──────────────────────────────│          │
  │  vire arrhes▶│                      │ « arrhes reçues »                    │
  │              │ ── J-10 : solde + CGU + livret (CC admin, PJ) ─▶ client + toi
  │  vire solde ▶│                      │ « solde reçu »                       │
  │              │ (phase 2) ─ facture ─▶ Dext                                 │
```
