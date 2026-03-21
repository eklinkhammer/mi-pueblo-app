defmodule FenceWeb.CoreComponents do
  @moduledoc """
  Minimal core UI components for the Fence web view.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  attr :kind, :atom, required: true
  attr :flash, :map, required: true

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      class={[
        "fixed top-4 right-4 z-50 rounded-lg p-4 shadow-lg text-sm max-w-sm",
        @kind == :info && "bg-green-50 text-green-800 border border-green-200",
        @kind == :error && "bg-red-50 text-red-800 border border-red-200"
      ]}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide()}
    >
      {msg}
    </div>
    """
  end

  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 active:bg-blue-800",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :rest, :global

  def input(assigns) do
    ~H"""
    <div>
      <label :if={@label} class="block text-sm font-medium text-gray-700 mb-1">{@label}</label>
      <input
        type={@type}
        name={@field.name}
        id={@field.id}
        value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
        class="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
        {@rest}
      />
      <.field_errors errors={@field.errors} />
    </div>
    """
  end

  defp field_errors(assigns) do
    ~H"""
    <div :for={msg <- @errors} class="mt-1 text-sm text-red-600">
      {msg}
    </div>
    """
  end
end
