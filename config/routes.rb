Rails.application.routes.draw do
  root to: "pages#home"

  # Calendrier public + devis (sélection samedi → samedi)
  get "calendrier",       to: "bookings#calendar", as: :calendar
  get "calendrier/quote", to: "bookings#quote",    as: :calendar_quote

  # Demande de réservation + suivi client (accès par token, sans login)
  resources :reservations, only: %i[create show], param: :token

  namespace :admin do
    root to: "dashboard#index"
    resources :weekly_rates do
      collection do
        get  :bulk_edit,   path: "bulk"
        post :bulk_update, path: "bulk"
      end
    end
    resources :bookings, only: %i[index show new create edit update destroy] do
      collection do
        get :archived
      end
      member do
        patch :confirm
        patch :reject
        patch :cancel
      end
    end
    resources :invoices, only: %i[index show update] do
      collection do
        get :archived
      end
      member do
        patch :mark_received
        patch :mark_awaiting
        patch :archive
      end
    end
    resource :booking_setting, only: %i[show update]
    resource :tourist_tax_periods, only: :update
    resources :clients, only: %i[show edit update]
  end
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
