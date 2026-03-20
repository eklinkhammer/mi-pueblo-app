defmodule FenceWeb.Presence do
  use Phoenix.Presence,
    otp_app: :fence,
    pubsub_server: Fence.PubSub
end
