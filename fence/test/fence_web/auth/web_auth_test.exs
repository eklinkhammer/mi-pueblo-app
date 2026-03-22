defmodule FenceWeb.WebAuthTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias FenceWeb.WebAuth

  describe "on_mount/4" do
    test "valid share token assigns current_user" do
      user = create_user()
      st = create_share_token(user)

      socket = %Phoenix.LiveView.Socket{
        endpoint: FenceWeb.Endpoint,
        assigns: %{__changed__: %{}}
      }

      assert {:cont, socket} =
               WebAuth.on_mount(:ensure_authenticated, %{}, %{"share_token" => st.token}, socket)

      assert socket.assigns.current_user.id == user.id
    end

    test "missing token halts with redirect" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: FenceWeb.Endpoint,
        assigns: %{__changed__: %{}}
      }

      assert {:halt, socket} =
               WebAuth.on_mount(:ensure_authenticated, %{}, %{}, socket)

      assert socket.redirected == {:redirect, %{status: 302, to: "/web/unauthorized"}}
    end

    test "invalid token halts with redirect" do
      socket = %Phoenix.LiveView.Socket{
        endpoint: FenceWeb.Endpoint,
        assigns: %{__changed__: %{}}
      }

      assert {:halt, socket} =
               WebAuth.on_mount(
                 :ensure_authenticated,
                 %{},
                 %{"share_token" => "bogus-token"},
                 socket
               )

      assert socket.redirected == {:redirect, %{status: 302, to: "/web/unauthorized"}}
    end
  end
end
