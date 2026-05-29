defmodule FenceWeb.Router do
  use FenceWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug FenceWeb.LocalePlug
  end

  pipeline :authenticated do
    plug FenceWeb.AuthPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FenceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :web_authenticated do
    plug FenceWeb.ShareTokenPlug
  end

  scope "/api/v1", FenceWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/google", AuthController, :google
    post "/auth/refresh", AuthController, :refresh
    post "/auth/anonymous-join", AuthController, :anonymous_join
    post "/auth/anonymous-create", AuthController, :anonymous_create
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
  end

  scope "/api/v1", FenceWeb do
    pipe_through [:api, :authenticated]

    get "/me", AuthController, :me
    put "/me", AuthController, :update_me
    delete "/me", AuthController, :delete_me
    post "/me/device-token", AuthController, :register_device_token

    # Groups
    get "/groups", GroupController, :index
    post "/groups", GroupController, :create
    get "/groups/:id", GroupController, :show
    put "/groups/:id", GroupController, :update
    delete "/groups/:id", GroupController, :delete
    post "/groups/join", GroupController, :join
    get "/groups/:id/members", GroupController, :members
    delete "/groups/:id/members/:user_id", GroupController, :remove_member
    post "/groups/:id/invites", GroupController, :create_invite
    get "/groups/:id/sharing-mode", GroupController, :show_sharing_mode
    put "/groups/:id/sharing-mode", GroupController, :update_sharing_mode
    get "/groups/:id/notification-preferences", GroupController, :show_notification_preferences
    put "/groups/:id/notification-preferences", GroupController, :update_notification_preferences
    # Visibility
    get "/groups/:id/visibility", VisibilityController, :index
    put "/groups/:id/visibility/:user_id", VisibilityController, :update

    # Geofences
    get "/my-geofences", GeofenceController, :my_geofences
    post "/geofence-events", GeofenceEventController, :create
    get "/groups/:id/geofences", GeofenceController, :index
    post "/groups/:id/geofences", GeofenceController, :create
    get "/groups/:gid/geofences/:fid", GeofenceController, :show
    put "/groups/:gid/geofences/:fid", GeofenceController, :update
    delete "/groups/:gid/geofences/:fid", GeofenceController, :delete
    get "/groups/:gid/geofences/:fid/activity", GeofenceController, :activity
    post "/groups/:gid/geofences/:fid/claim-home", GeofenceController, :claim_home
    delete "/groups/:gid/geofences/:fid/claim-home", GeofenceController, :unclaim_home

    # Geofence subscriptions & opt-outs
    get "/geofences/:id/subscription", GeofenceController, :show_subscription
    put "/geofences/:id/subscription", GeofenceController, :upsert_subscription
    post "/geofences/:id/opt-out", GeofenceController, :create_opt_out
    delete "/geofences/:id/opt-out", GeofenceController, :delete_opt_out

    # Location
    post "/location", LocationController, :report
    get "/groups/:id/locations", LocationController, :group_locations

    # History
    get "/users/:user_id/history", HistoryController, :show

    # Geocoding
    get "/geocode", GeocodingController, :search
  end

  scope "/", FenceWeb do
    pipe_through :browser

    live "/", LandingLive
  end

  scope "/web", FenceWeb do
    pipe_through :browser

    live "/register", RegisterLive
    live "/login", LoginLive
    post "/auth/register", WebAuthController, :register
    post "/auth/login", WebAuthController, :login
    post "/auth/logout", WebAuthController, :logout
  end

  scope "/web", FenceWeb do
    pipe_through [:browser, :web_authenticated]

    live_session :authenticated, on_mount: [{FenceWeb.WebAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive
      live "/map", MapLive
      live "/groups/:group_id/geofences/new", GeofenceCreateLive
      live "/groups/:group_id/geofences/:id", GeofenceDetailLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fence, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: FenceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
