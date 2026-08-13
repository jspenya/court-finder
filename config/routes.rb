Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "searches#new"
  post "search", to: "searches#create", as: :search
  get "search/venues/:id", to: "search_venues#show", as: :search_venue
end
