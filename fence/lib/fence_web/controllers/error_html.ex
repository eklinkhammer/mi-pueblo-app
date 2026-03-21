defmodule FenceWeb.ErrorHTML do
  @moduledoc """
  Simple HTML error renderer.
  """
  use FenceWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
