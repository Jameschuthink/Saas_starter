defmodule SaasTemplateWeb.Router do
  use SaasTemplateWeb, :router

  import SaasTemplateWeb.UserAuth

  pipeline :mounted_apps do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SaasTemplateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :admin_protected do
    plug SaasTemplateWeb.Plugs.AdminAuthentication
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SaasTemplateWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/terms", LegalController, :terms
    get "/privacy", LegalController, :privacy
    get "/changelog", ChangelogController, :index
    get "/sitemap.xml", SitemapController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", SaasTemplateWeb do
  #   pipe_through :api
  # end

  # Feature flags UI panel - admin protected
  scope path: "/feature-flags" do
    pipe_through [:browser, :admin_protected]
    forward "/", FunWithFlags.UI.Router, namespace: "feature-flags"
  end

  # Other admin protected pages
  scope "/admin" do
    pipe_through [:browser, :admin_protected]

    # Design system preview
    get "/design-system", SaasTemplateWeb.PageController, :design_system
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:saas_template, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      # LiveDashboard
      live_dashboard "/dashboard", metrics: SaasTemplateWeb.Telemetry

      # Swoosh mailbox preview
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SaasTemplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SaasTemplateWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SaasTemplateWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SaasTemplateWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new

      live "/dashboard", DashboardLive, :index
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
