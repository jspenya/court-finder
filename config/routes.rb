Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "searches#new"
  post "search", to: "searches#create", as: :search
end
