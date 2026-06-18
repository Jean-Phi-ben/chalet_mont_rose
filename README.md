# Chalet Mont Rose

Application Ruby on Rails 8 pour le site de location du **Chalet Mont Rose** (Le Bettex, Saint-Gervais-les-Bains — domaine Évasion Mont-Blanc). Elle gère la vitrine publique, le calendrier de réservation samedi→samedi, le devis en ligne, le parcours de réservation client (contrat à signer + caution), et un back-office complet (tarifs, réservations, factures PDF, clients).

Production : **https://chaletmontrose.fr**

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Pré-requis](#pré-requis)
- [Installation](#installation)
- [Variables d'environnement](#variables-denvironnement)
- [Développement](#développement)
- [Commandes utiles](#commandes-utiles)
- [Domaine métier](#domaine-métier)
- [Environnements](#environnements)
- [Déploiement en production](#déploiement-en-production)
- [Sauvegardes](#sauvegardes)
- [Structure du projet](#structure-du-projet)
- [Routes principales](#routes-principales)

---

## Fonctionnalités

### Front-office (public, sans compte)

- **Accueil** vitrine (`/`).
- **Calendrier & tarifs** (`/calendrier`) : grille mensuelle samedi→samedi, prix indicatif par nuit (prix de la semaine ÷ 7), jours bloqués et jours de transition. Sélection d'un séjour en un clic (l'arrivée/départ se cale sur le samedi).
- **Devis instantané** (`/calendrier/quote`, JSON) : hébergement + frais de ménage + taxe de séjour + arrhes (30 %).
- **Demande de réservation** puis **suivi client par lien à token** (sans login) :
  - consultation de la réservation,
  - **signature électronique du contrat** : OTP envoyé par email, signature embarquée, génération du **PDF de contrat signé**,
  - **caution en ligne** via Swikly.

### Back-office (`/admin`, réservé aux comptes `admin`)

- **Tableau de bord**.
- **Tarifs hebdomadaires** : CRUD + **édition en lot** sur une plage de dates (`/admin/weekly_rates/bulk`).
- **Réservations** : confirmer / refuser / annuler, archiver, **relance du solde**, renvoi d'emails.
- **Factures** (arrhes + solde, PDF) : marquer reçue / en attente, archiver.
- **Paramètres de réservation** : frais de ménage, taxe de séjour.
- **Périodes de taxe de séjour**, **clients**, **documents**, **journal des emails**, **notes**.

### Transverse

- **Génération de PDF** (Prawn) : factures et contrats.
- **Emails transactionnels** (Gmail SMTP) avec **journalisation** (`EmailLog`).
- **Jobs en arrière-plan** (Solid Queue) : facture, contrat, contrat signé, caution, relance.

---

## Stack technique

- **Ruby** 3.3.5 — **Rails** ~> 8.1.2
- **Base de données** : PostgreSQL (`pg`)
- **Serveur web** : Puma, **Thruster** en production (HTTP/2, compression, cache assets)
- **Front-end** : Hotwire (Turbo + Stimulus), Importmap (pas de bundler JS), Propshaft, **Tailwind CSS** (`tailwindcss-rails`) + **FlyonUI**, Font Awesome
- **Auth & autorisation** : `bcrypt` (`has_secure_password`), OmniAuth (Google / Facebook / Apple), **Pundit**
- **Cache / jobs / cable** : Solid Cache, Solid Queue, Solid Cable (back-ends PostgreSQL)
- **PDF** : `prawn` + `prawn-table`
- **HTTP sortant** : `faraday` (intégration **Swikly** pour la caution)
- **Images** : `image_processing` (Active Storage)
- **Variables d'environnement** : `dotenv-rails` (`.env`)
- **Conteneurisation** : Docker (+ Kamal scaffoldé, voir [Déploiement](#déploiement-en-production))
- **Qualité & sécurité** : RuboCop (Rails Omakase), Brakeman, bundler-audit, importmap audit
- **Tests** : Minitest + Capybara + Selenium

---

## Pré-requis

- Ruby 3.3.5 (voir [.ruby-version](.ruby-version))
- PostgreSQL en local
- `npm` (uniquement pour récupérer **FlyonUI**, voir [package.json](package.json)) ; l'app elle-même n'utilise pas de bundler JS (importmap).

---

## Installation

```bash
bundle install
npm install
cp .env.example .env        # puis renseigner les valeurs
bin/rails db:prepare        # create + migrate (+ seed sur base neuve)
bin/rails weekly_rates:seed # grille tarifaire indicative samedi→samedi
```

---

## Variables d'environnement

Toutes les valeurs sensibles passent par l'environnement, **jamais** par le code versionné.

- En **développement** : fichier `.env` (gitignoré). Le gabarit [.env.example](.env.example) liste toutes les clés (OAuth, mentions légales de facturation, RIB, Gmail SMTP, Swikly…).
- En **production** : fichier `~/.chalet_env` sur le serveur (mode `600`), chargé via `docker run --env-file`.

Clés notables :

| Clé | Usage |
|-----|-------|
| `GMAIL_SMTP_USERNAME`, `GMAIL_SMTP_APP_PASSWORD` | Envoi d'emails via Gmail SMTP (mot de passe d'application) |
| `MAILER_FROM`, `MAILER_OWNER_EMAIL` | Expéditeur et destinataire propriétaire |
| `SWIKLY_*`, `CAUTION_AMOUNT` | Caution en ligne |
| `COMPANY_*` | Mentions légales / RIB sur les PDF de factures |
| `*_CLIENT_ID` / `*_SECRET` | OmniAuth (Google / Facebook / Apple) |

> `config/master.key` (déchiffrement des credentials Rails) est **gitignoré**. En production, la clé est fournie via `RAILS_MASTER_KEY`.

---

## Développement

Lancer Rails **et** le watcher Tailwind ensemble ([Procfile.dev](Procfile.dev)) :

```bash
bin/dev
```

- `web` : `bin/rails server` → http://localhost:3000
- `css` : `bin/rails tailwindcss:watch`

Alternatives :

```bash
bin/rails server              # serveur seul
bin/rails tailwindcss:build   # recompiler Tailwind une fois
```

---

## Commandes utiles

### Base de données

```bash
bin/rails db:prepare      # create + migrate (idempotent)
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:seed         # comptes de test (écrase puis recrée)
bin/rails weekly_rates:seed   # (re)génère la grille tarifaire samedi→samedi
bin/rails console
bin/rails dbconsole
```

### Tests & qualité

```bash
bin/rails test            # tests unitaires
bin/rails test:system     # tests système (Capybara/Selenium)
bin/rubocop               # linter (Rails Omakase)
bin/brakeman              # analyse de sécurité statique
bin/bundler-audit         # CVE dans les gems
bin/ci                    # pipeline CI complète (runner natif Rails 8)
```

> La CI GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) rejoue ces vérifications sur chaque push et pull request.

### Vérifier les écarts dev → prod

Avant un déploiement, comparer ce qui va changer (code et base de données) :

```bash
# CODE — ce qui est committé en local mais pas encore poussé/déployé
git fetch origin
git status -s                        # changements locaux non committés
git log --oneline origin/main..HEAD  # commits en attente de déploiement

# SCHÉMA / MIGRATIONS — comparer les migrations appliquées dev vs prod
bin/rails db:migrate:status                                                          # dev (en local)
ssh jeanphi@100.73.93.75 'docker exec chalet_mont_rose bin/rails db:migrate:status'  # prod
# Toute migration présente en dev et "down"/absente en prod s'appliquera au prochain déploiement.
```

> Astuce : pour un diff **exact** code/schéma, maintenir une branche `production` pointant sur le commit déployé
> (`git tag -f production <sha> && git push -f origin production`), puis :
> `git diff production..main` et `git diff production..main -- db/migrate db/schema.rb`.

---

## Domaine métier

**Modèles principaux** (`app/models`) : `User`, `Session`, `Current`, `Booking`, `Client`, `WeeklyRate`, `BookingSetting`, `TouristTaxPeriod`, `Invoice`, `Contract`, `Caution`, `Document`, `EmailLog`, `Note`.

- **Réservation** (`Booking`) — statuts : `pending` → `confirmed` / `rejected` / `cancelled`. Seules les `confirmed` bloquent le calendrier.
- **Tarification** (`Pricing`, `app/services/pricing.rb`) — location à la **semaine, samedi→samedi** ; montants en **centimes** ; arrhes 30 % ; frais de ménage et taxe de séjour issus de `BookingSetting`. La grille indicative (saisonnalité ski / vacances scolaires FR & Genève) est dans [lib/tasks/weekly_rates.rake](lib/tasks/weekly_rates.rake).
- **Facturation PDF** (`InvoicePdf`, `GenerateInvoiceJob`) — facture d'arrhes à la confirmation, facture de solde ensuite.
- **Contrat & signature** (`ContractPdf`, `ContractTemplate`, OTP par email, `GenerateSignedContractPdfJob`) — signature électronique embarquée, sans prestataire externe.
- **Caution** (`SwiklyProvider`, `CreateCautionJob`, webhook `/webhooks/swikly`).
- **Emails** (`BookingMailer`, envoyés via `dispatch` + `EmailLog`) : `new_request_to_owner`, `acknowledgement_to_client`, `confirmation`, `rejected`, `balance_reminder`, `signed_contract`, `contract_otp`.
- **Autorisations** : Pundit, accès admin via `User#admin?`.

---

## Environnements

### Développement (local, WSL)

- PostgreSQL local, secrets dans `.env` (dotenv).
- Emails : Gmail SMTP **activé uniquement si `GMAIL_SMTP_USERNAME` est présent** (sinon délivrance désactivée). URLs des mails en `localhost:3000`.

### Production (`jpserver`)

Hébergement auto-géré sur la machine **jpserver**, accessible en SSH via **Tailscale** :

```bash
ssh jeanphi@100.73.93.75          # MagicDNS : jpserver.tail3db033.ts.net
```

- **Application** : conteneur Docker `chalet_mont_rose` en `--network host`, écoutant sur le **port 8000** (Thruster → Puma), `--restart unless-stopped`.
- **Base de données** : PostgreSQL **sur l'hôte** (`127.0.0.1:5432`) — bases `chalet_mont_rose_production` (+ `_cache` / `_queue` / `_cable`). La base n'est pas dans le conteneur : un redéploiement ne touche pas aux données.
- **Exposition publique** : tunnel **Cloudflare** (`cloudflared`) → `chaletmontrose.fr` et `www.chaletmontrose.fr` vers `localhost:8000`. Aucun port entrant ouvert sur la machine.
- **Secrets** : `~/.chalet_env` (mode `600`), chargé via `--env-file` (mot de passe DB, `RAILS_MASTER_KEY`, identifiants Gmail SMTP, `MAILER_FROM`).
- **Stockage de fichiers** : volume Docker `chalet_mont_rose_storage` monté sur `/rails/storage` (Active Storage) → les PDF générés survivent aux redéploiements.
- **Réseau** : **dual-stack IPv4 + IPv6** (IPv4 activée le 2026-06-18 via DHCP). L'image est buildée **sur le serveur** lors du déploiement (voir ci-dessous).

---

## Déploiement en production

Déploiement **en une commande** via [bin/deploy](bin/deploy), à lancer depuis un poste où `ssh jeanphi@100.73.93.75` fonctionne (WSL ou Git Bash, Tailscale actif) :

```bash
git push origin main   # (recommandé : garder origin à jour)
bin/deploy             # déploie le commit courant (HEAD)
```

Le script :
1. copie le code (HEAD) sur le serveur via `git archive`, **en LF forcé** (anti-CRLF Windows) ;
2. build l'image **sur le serveur** ;
3. bascule le conteneur (réseau host, port 8000, volume `storage`, secrets via `--env-file ~/.chalet_env`) — l'entrypoint exécute `db:prepare` (migrations) au démarrage ;
4. **healthcheck `/up`** avec **rollback automatique** si KO ;
5. tague le commit déployé (`git tag -f production`) et conserve l'image précédente sous `chalet_mont_rose:rollback`.

**Rollback manuel** (après coup) :

```bash
ssh jeanphi@100.73.93.75 'docker rm -f chalet_mont_rose; docker run -d --name chalet_mont_rose \
  --network host --restart unless-stopped --env-file /home/jeanphi/.chalet_env \
  -v chalet_mont_rose_storage:/rails/storage \
  -e HTTP_PORT=8000 -e RAILS_ENV=production -e PGHOST=127.0.0.1 chalet_mont_rose:rollback'
```

> ℹ️ **Pourquoi pas Kamal ?** Bien que présent dans le `Gemfile`, Kamal s'intègre mal à cette topologie (tunnel Cloudflare en ingress + PostgreSQL sur l'hôte + réseau host imposent de désactiver kamal-proxy, ce qui annule son principal intérêt, le zéro-downtime). Le script `bin/deploy` couvre le besoin (une commande, rollback) sans cette friction.

---

## Sauvegardes

Dispositif à deux niveaux (dump PostgreSQL en format `-Fc`, restaurable via `pg_restore`).

- **Sur le serveur** — `~/bin/chalet_backup.sh`, **cron quotidien 03:30**, dumps dans `~/backups/` (symlink `chalet_prod_latest.dump`), rétention **14 jours**.
- **Hors-site (poste de dev)** — récupération automatique du dernier dump via Tailscale : `pull_backup.ps1` + tâche planifiée Windows **`ChaletBackupPull` (quotidienne 12:30)** vers `C:\Users\jp-be\chalet_backups\`, rétention **30 jours**. Cette copie sur une **machine distincte** protège contre la perte du serveur.

**Restaurer un dump :**

```bash
pg_restore -h 127.0.0.1 -U chalet_mont_rose -d chalet_mont_rose_production \
  --clean --if-exists chalet_prod_AAAAMMJJ_HHMMSS.dump
```

> Le pull hors-site s'exécute en `BatchMode` : si Tailscale SSH redemande une ré-authentification, le pull du jour échoue proprement (loggé dans `pull.log`) ; le backup serveur, lui, n'est pas affecté.

---

## Structure du projet

```
chalet_mont_rose/
├── app/
│   ├── controllers/
│   │   ├── admin/            # back-office : dashboard, weekly_rates, bookings,
│   │   │                     #   invoices, booking_setting, clients, documents,
│   │   │                     #   email_logs, notes, tourist_tax_periods
│   │   ├── bookings_controller.rb   # calendrier + devis JSON (front)
│   │   ├── reservations_controller.rb  # demande + contrat + signature (token)
│   │   ├── webhooks/         # swikly
│   │   ├── pages_controller.rb
│   │   ├── sessions_controller.rb
│   │   └── passwords_controller.rb
│   ├── jobs/                 # generate_invoice, send_contract,
│   │                         #   generate_signed_contract_pdf, create_caution,
│   │                         #   balance_reminder
│   ├── mailers/              # booking_mailer, passwords_mailer
│   ├── models/               # Booking, WeeklyRate, Invoice, Contract, Caution, …
│   ├── policies/             # Pundit (booking, invoice, weekly_rate, …)
│   ├── services/             # pricing, invoice_pdf, contract_pdf,
│   │                         #   contract_template, swikly_provider,
│   │                         #   school_holidays, booking_email_planner
│   ├── javascript/           # contrôleurs Stimulus (importmap)
│   └── views/                # front (pages, bookings, reservations) + admin
├── bin/                      # bin/dev, bin/rails, bin/ci, bin/kamal, …
├── config/
│   ├── routes.rb
│   ├── database.yml
│   ├── deploy.yml            # Kamal (scaffoldé, non utilisé)
│   └── environments/
├── db/                       # migrate/, schema.rb, seeds.rb
├── lib/tasks/                # weekly_rates.rake
├── storage/                  # Active Storage (Disk)
├── .github/workflows/ci.yml  # CI (brakeman, audit, rubocop, tests, system)
├── Dockerfile                # build production (Tailwind v4 + FlyonUI via npm)
├── Procfile.dev              # web + css watcher
├── Gemfile
└── package.json              # FlyonUI
```

---

## Routes principales

Définies dans [config/routes.rb](config/routes.rb) :

| Route | Cible |
|-------|-------|
| `GET /` | `pages#home` |
| `GET /calendrier` | `bookings#calendar` (calendrier public) |
| `GET /calendrier/quote` | `bookings#quote` (devis JSON) |
| `resources :reservations` (`:token`) | demande, suivi, `contract`, `otp`, `sign`, `pdf` |
| `POST /webhooks/swikly` | `webhooks/swikly#create` |
| `namespace :admin` | dashboard, weekly_rates (+ `bulk`), bookings, invoices, booking_setting, clients, documents, email_logs, notes, tourist_tax_periods |
| `resource :session` | login / logout |
| `resources :passwords` (`:token`) | réinitialisation du mot de passe |
| `GET /up` | healthcheck Rails |
