defmodule Fence.FCMStarter do
  @moduledoc """
  Starts Goth + FCM with retry. If the connection fails (e.g. TLS issues),
  the app continues running and this process retries every 30 seconds.
  """
  use GenServer

  require Logger

  @retry_interval :timer.seconds(30)

  def start_link(credentials) do
    GenServer.start_link(__MODULE__, credentials, name: __MODULE__)
  end

  @impl true
  def init(credentials) do
    send(self(), :start)
    {:ok, %{credentials: credentials, started: false}}
  end

  @impl true
  def handle_info(:start, %{started: true} = state), do: {:noreply, state}

  def handle_info(:start, %{credentials: credentials} = state) do
    case start_fcm(credentials) do
      :ok ->
        Logger.info("[FCM] Goth + FCM started successfully")
        {:noreply, %{state | started: true}}

      {:error, reason} ->
        Logger.warning("[FCM] Failed to start: #{inspect(reason)}, retrying in 30s")
        Process.send_after(self(), :start, @retry_interval)
        {:noreply, state}
    end
  end

  defp start_fcm(credentials) do
    goth_spec = {Goth, name: Fence.Goth, source: {:service_account, credentials, []}}

    with {:ok, _goth_pid} <- start_child(goth_spec),
         {:ok, _fcm_pid} <- start_child(Fence.FCM) do
      :ok
    else
      {:error, _reason} = err ->
        # Clean up Goth if it started but FCM failed
        stop_child(Fence.Goth)
        err
    end
  catch
    kind, reason ->
      stop_child(Fence.Goth)
      {:error, {kind, reason}}
  end

  defp start_child(spec) do
    case DynamicSupervisor.start_child(Fence.FCMDynSupervisor, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = err -> err
    end
  end

  defp stop_child(name) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Fence.FCMDynSupervisor, pid)
    end
  end
end
