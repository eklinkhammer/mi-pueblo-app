defmodule FenceWeb.AvatarController do
  use FenceWeb, :controller

  require Logger

  alias Fence.Accounts

  @max_size 5 * 1_024 * 1_024
  @allowed_types ~w(image/jpeg image/png image/webp)
  @upload_dir Path.join(:code.priv_dir(:fence), "static/uploads/avatars")

  def upload(conn, %{"avatar" => %Plug.Upload{} = upload}) do
    user = conn.assigns.current_user

    with :ok <- validate_type(upload.content_type),
         :ok <- validate_size(upload.path) do
      File.mkdir_p!(@upload_dir)
      dest = Path.join(@upload_dir, "#{user.id}.jpg")

      case System.cmd("convert", [
             upload.path,
             "-resize",
             "256x256^",
             "-gravity",
             "center",
             "-extent",
             "256x256",
             "-quality",
             "85",
             dest
           ]) do
        {_, 0} ->
          avatar_url = "/uploads/avatars/#{user.id}.jpg"
          {:ok, updated_user} = Accounts.update_avatar(user, avatar_url)

          json(conn, %{avatar_url: updated_user.avatar_url})

        {output, code} ->
          Logger.error("[Avatar] convert failed (code=#{code}): #{output}")

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: %{code: "processing_failed", message: "Image processing failed"}})
      end
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "invalid_file", message: reason}})
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_file", message: "Missing avatar file"}})
  end

  def delete(conn, _params) do
    user = conn.assigns.current_user
    path = Path.join(@upload_dir, "#{user.id}.jpg")

    if File.exists?(path), do: File.rm(path)

    {:ok, _user} = Accounts.update_avatar(user, nil)
    send_resp(conn, :no_content, "")
  end

  defp validate_type(content_type) when content_type in @allowed_types, do: :ok
  defp validate_type(_), do: {:error, "File must be JPEG, PNG, or WebP"}

  defp validate_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_size -> :ok
      {:ok, _} -> {:error, "File must be 5MB or less"}
      _ -> {:error, "Could not read file"}
    end
  end
end
