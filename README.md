# Chalet Mont Rose

Application Ruby on Rails 8 pour le site du Chalet Mont Rose.

## Stack technique

- **Ruby** 3.3.5
- **Rails** ~> 8.1.2
- **Base de données** : PostgreSQL (`pg` ~> 1.1)
- **Serveur web** : Puma (>= 5.0), avec Thruster pour la production
- **Front-end** :
  - Hotwire (Turbo + Stimulus)
  - Importmap (pas de bundler JS)
  - Propshaft (asset pipeline)
  - Tailwind CSS (`tailwindcss-rails`) + FlyonUI
  - Font Awesome (`font-awesome-sass`)
- **Authentification & autorisation** :
  - `bcrypt` (`has_secure_password`)
  - OmniAuth : Google, Facebook, Apple
  - Pundit (politiques d'autorisation)
- **Cache / jobs / cable** : Solid Cache, Solid Queue, Solid Cable (adapters basés sur la base de données)
- **Variables d'environnement** : `dotenv-rails` (fichier `.env`)
- **Déploiement** : Kamal + Docker
- **Qualité & sécurité** : RuboCop (Rails Omakase), Brakeman, bundler-audit
- **Tests** : Minitest + Capybara + Selenium

## Pré-requis

- Ruby 3.3.5 (voir [.ruby-version](.ruby-version))
- PostgreSQL en local
- Node n'est pas requis pour exécuter l'app (importmap), mais `npm` est utilisé pour FlyonUI (voir [package.json](package.json))

## Installation

```bash
bundle install
npm install
bin/rails db:create db:migrate db:seed
```

Copier / créer le fichier `.env` avec les variables requises (OAuth, etc.).

## Comptes de test (créés par `db:seed`)

Définis dans [db/seeds.rb](db/seeds.rb) :

| Rôle   | Email                  | Mot de passe  |
|--------|------------------------|---------------|
| Admin  | `admin@prestige.com`   | `password123` |
| Client | `client@prestige.com`  | `password123` |

> Recharger les comptes (efface puis recrée) : `bin/rails db:seed`

## Démarrer le serveur de développement

Lancer Rails **et** le watcher Tailwind ensemble via le Procfile :

```bash
bin/dev
```

Ce script utilise [Procfile.dev](Procfile.dev) qui démarre :
- `web` : `bin/rails server` (par défaut sur http://localhost:3000)
- `css` : `bin/rails tailwindcss:watch`

### Alternatives

```bash
# Serveur seul
bin/rails server

# Recompiler Tailwind une fois
bin/rails tailwindcss:build
```

### Console & base de données

```bash
bin/rails console
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:reset
```

### Tests & qualité

```bash
bin/rails test                  # tests unitaires
bin/rails test:system           # tests système (Capybara/Selenium)
bin/rubocop                     # linter
bin/brakeman                    # analyse de sécurité
bundle exec bundler-audit       # audit des gems
```

### Déploiement (Kamal)

```bash
bin/kamal deploy
```

## Structure du projet

```
chalet_mont_rose/
├── app/
│   ├── assets/            # CSS Tailwind, images
│   ├── channels/          # Action Cable
│   ├── controllers/
│   │   ├── admin/         # Espace admin (dashboard)
│   │   ├── pages_controller.rb
│   │   ├── sessions_controller.rb
│   │   └── passwords_controller.rb
│   ├── helpers/
│   ├── javascript/        # Contrôleurs Stimulus (importmap)
│   ├── jobs/              # Active Job (Solid Queue)
│   ├── mailers/
│   ├── models/            # User, Session, Current, …
│   ├── policies/          # Pundit
│   └── views/
│       ├── admin/
│       ├── layouts/
│       ├── pages/         # home.html.erb
│       ├── shared/        # _navbar.html.erb, …
│       ├── sessions/
│       ├── passwords/
│       ├── passwords_mailer/
│       └── pwa/
├── bin/                   # bin/dev, bin/rails, bin/kamal, …
├── config/
│   ├── routes.rb
│   ├── database.yml       # PostgreSQL
│   ├── deploy.yml         # Kamal
│   ├── environments/
│   └── initializers/
├── db/
│   ├── migrate/
│   ├── schema.rb
│   └── seeds.rb
├── lib/
├── public/
├── storage/               # Active Storage (local)
├── test/
├── vendor/
├── .kamal/                # secrets / hooks Kamal
├── Dockerfile
├── Procfile.dev           # web + css watcher
├── Gemfile
└── package.json           # FlyonUI
```

## Routes principales

Définies dans [config/routes.rb](config/routes.rb) :

- `GET /` → `pages#home`
- `/admin` → `admin/dashboard#index` (namespace `admin`)
- `resource :session` (login / logout)
- `resources :passwords, param: :token` (reset mot de passe)
- `GET /up` → healthcheck Rails
