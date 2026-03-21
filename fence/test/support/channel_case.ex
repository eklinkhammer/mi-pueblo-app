defmodule FenceWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import FenceWeb.ChannelCase

      @endpoint FenceWeb.Endpoint
    end
  end

  setup tags do
    Fence.DataCase.setup_sandbox(tags)
    :ok
  end
end
