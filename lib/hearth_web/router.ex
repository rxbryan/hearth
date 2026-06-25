defmodule HearthWeb.Router do
  use HearthWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", HearthWeb do
    pipe_through :api
  end
end
