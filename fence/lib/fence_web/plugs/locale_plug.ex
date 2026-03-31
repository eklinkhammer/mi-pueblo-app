defmodule FenceWeb.LocalePlug do
  @moduledoc """
  Reads the Accept-Language header and sets the Gettext locale.
  If the user is authenticated, persists the locale to the user record.
  """
  import Plug.Conn

  @supported_locales ["en", "es"]

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = parse_accept_language(conn) || "en"
    Gettext.put_locale(FenceWeb.Gettext, locale)

    conn
    |> assign(:locale, locale)
    |> register_before_send(&maybe_persist_locale/1)
  end

  defp parse_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] ->
        header
        |> String.split(",")
        |> Enum.map(&parse_lang_tag/1)
        |> Enum.sort_by(fn {_lang, q} -> q end, :desc)
        |> Enum.find_value(fn {lang, _q} -> if lang in @supported_locales, do: lang end)

      _ ->
        nil
    end
  end

  defp parse_lang_tag(tag) do
    case String.split(String.trim(tag), ";") do
      [lang] ->
        {normalize_lang(lang), 1.0}

      [lang, quality] ->
        q =
          case Regex.run(~r/q=([\d.]+)/, quality) do
            [_, val] -> String.to_float(val)
            _ -> 1.0
          end

        {normalize_lang(lang), q}
    end
  end

  defp normalize_lang(lang) do
    lang
    |> String.trim()
    |> String.downcase()
    |> String.split("-")
    |> hd()
  end

  defp maybe_persist_locale(conn) do
    with %{current_user: user} <- conn.assigns,
         locale when locale != user.locale <- conn.assigns[:locale] do
      Fence.Accounts.update_user(user, %{"locale" => locale})
    end

    conn
  end
end
