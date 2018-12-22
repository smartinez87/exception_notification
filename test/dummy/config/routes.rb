Dummy::Application.routes.draw do
  resources :posts, only: [:create, :show]
end
