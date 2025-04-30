Rails.application.routes.draw do
  resources :products, only: [:index, :show]
  # get 'products', to: 'product#index'
end
