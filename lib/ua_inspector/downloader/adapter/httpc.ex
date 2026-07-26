defmodule UAInspector.Downloader.Adapter.Httpc do
  @moduledoc false

  alias UAInspector.Config

  @behaviour UAInspector.Downloader.Adapter

  @default_http_opts [timeout: 30_000]

  @impl UAInspector.Downloader.Adapter
  def read_remote(location) do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)

    http_opts = Keyword.merge(default_http_opts(), Config.get(:http_opts, []))
    request = {String.to_charlist(location), []}

    case :httpc.request(:get, request, http_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _, _}} -> {:error, {:status, status, location}}
      {:error, _} = error -> error
    end
  end

  defp default_http_opts, do: Keyword.put(@default_http_opts, :ssl, ssl_opts())

  defp ssl_opts do
    opts = [
      verify: :verify_peer,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

    try do
      Keyword.put(opts, :cacerts, :public_key.cacerts_get())
    rescue
      _ -> opts
    end
  end
end
