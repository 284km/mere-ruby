Rails.application.routes.draw do
  get "/remembered", to: "notes#remembered"
  resources :notes, only: [:index, :create, :update, :destroy]
  root "notes#index"
end
