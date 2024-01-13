defmodule HappyHangerWeb.Router do
  use HappyHangerWeb, :router

  import HappyHangerWeb.SellerAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HappyHangerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_seller
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HappyHangerWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", HappyHangerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:happy_hanger, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HappyHangerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HappyHangerWeb do
    pipe_through [:browser, :redirect_if_seller_is_authenticated]

    live_session :redirect_if_seller_is_authenticated,
      on_mount: [{HappyHangerWeb.SellerAuth, :redirect_if_seller_is_authenticated}] do
      live "/sellers/register", SellerRegistrationLive, :new
      live "/sellers/log_in", SellerLoginLive, :new
      live "/sellers/reset_password", SellerForgotPasswordLive, :new
      live "/sellers/reset_password/:token", SellerResetPasswordLive, :edit
    end

    post "/sellers/log_in", SellerSessionController, :create
  end

  scope "/", HappyHangerWeb do
    pipe_through [:browser, :require_authenticated_seller]

    live_session :require_authenticated_seller,
      on_mount: [{HappyHangerWeb.SellerAuth, :ensure_authenticated}] do
      live "/sellers/settings", SellerSettingsLive, :edit
      live "/sellers/settings/confirm_email/:token", SellerSettingsLive, :confirm_email

      live "/products", ProductLive.Index, :index
      live "/products/new", ProductLive.Index, :new
      live "/products/:id/edit", ProductLive.Index, :edit

      live "/products/:id", ProductLive.Show, :show
      live "/products/:id/show/edit", ProductLive.Show, :edit

      live "/orders", OrderLive.Index, :index
      live "/orders/new", OrderLive.Index, :new
      live "/orders/:id/edit", OrderLive.Index, :edit

      live "/orders/:id", OrderLive.Show, :show
      live "/orders/:id/show/edit", OrderLive.Show, :edit
    end
  end

  scope "/", HappyHangerWeb do
    pipe_through [:browser]

    delete "/sellers/log_out", SellerSessionController, :delete

    live_session :current_seller,
      on_mount: [{HappyHangerWeb.SellerAuth, :mount_current_seller}] do
      live "/sellers/confirm/:token", SellerConfirmationLive, :edit
      live "/sellers/confirm", SellerConfirmationInstructionsLive, :new
    end
  end
end
