defmodule UAInspector.Downloader do
  @moduledoc """
  Fetches copies of the configured database files.

  All files will be stored in the configured database path with the default
  setting being the result of `Application.app_dir(:ua_inspector, "priv")`.

  Please consult `UAInspector.Config` for details on database configuration.

  ## Mix Task

  Please see `Mix.Tasks.UaInspector.Download` if you are interested in
  using a mix task to obtain your database files.
  """

  alias UAInspector.ClientHints
  alias UAInspector.Config
  alias UAInspector.Database
  alias UAInspector.Downloader.ShortCodeMapConverter
  alias UAInspector.ShortCodeMap

  @client_hints [
    ClientHints.Apps,
    ClientHints.Browsers
  ]

  @databases [
    Database.Bots,
    Database.BrowserEngines,
    Database.Clients,
    Database.DevicesHbbTV,
    Database.DevicesNotebooks,
    Database.DevicesRegular,
    Database.DevicesShellTV,
    Database.OSs,
    Database.VendorFragments
  ]

  @short_code_maps [
    ShortCodeMap.BrowserFamilies,
    ShortCodeMap.ClientBrowsers,
    ShortCodeMap.ClientHintBrowserMapping,
    ShortCodeMap.ClientHintOSMapping,
    ShortCodeMap.DesktopFamilies,
    ShortCodeMap.MobileBrowsers,
    ShortCodeMap.OSFamilies,
    ShortCodeMap.OSs,
    ShortCodeMap.VersionMappingFireOS,
    ShortCodeMap.VersionMappingLineageOS
  ]

  @typedoc """
  Remote location and reason of a failed file download.
  """
  @type download_error :: {remote :: String.t(), reason :: term}

  @doc """
  Performs download of all files.

  Failures of individual files are collected and returned instead of raising,
  leaving the decision on how to handle a partial download to the caller.
  """
  @spec download() :: :ok | {:error, [download_error]}
  def download do
    [:client_hints, :databases, :short_code_maps]
    |> Enum.flat_map(fn type ->
      case download(type) do
        :ok -> []
        {:error, errors} -> errors
      end
    end)
    |> maybe_errors()
  end

  @doc """
  Performs download of configured database files and short code maps.
  """
  @spec download(:client_hints | :databases | :short_code_maps) ::
          :ok | {:error, [download_error]}
  def download(:client_hints) do
    File.mkdir_p!(Config.database_path())

    @client_hints
    |> Enum.flat_map(fn client_hint ->
      {local, remote} = client_hint.source()
      target = Path.join([Config.database_path(), local])

      download_file(remote, target)
    end)
    |> maybe_errors()
  end

  def download(:databases) do
    File.mkdir_p!(Config.database_path())

    @databases
    |> Enum.flat_map(fn database ->
      Enum.flat_map(database.sources(), fn {_type, local, remote} ->
        target = Path.join([Config.database_path(), local])

        download_file(remote, target)
      end)
    end)
    |> maybe_errors()
  end

  def download(:short_code_maps) do
    File.mkdir_p!(Config.database_path())

    @short_code_maps
    |> Enum.flat_map(&download_short_code_map/1)
    |> maybe_errors()
  end

  defp download_file(remote, local) do
    case Config.downloader_adapter().read_remote(remote) do
      {:ok, content} ->
        :ok = File.write!(local, content)

        []

      {:error, reason} ->
        [{remote, reason}]
    end
  end

  defp download_short_code_map(short_code_map) do
    {local, remote} = short_code_map.source()

    yaml = Path.join(Config.database_path(), local)
    temp = "#{yaml}.tmp"

    case download_file(remote, temp) do
      [] ->
        :ok =
          short_code_map.var_name()
          |> ShortCodeMapConverter.extract(short_code_map.var_type(), temp)
          |> ShortCodeMapConverter.write_yaml(short_code_map.var_type(), yaml)

        :ok = File.rm!(temp)

        []

      errors ->
        errors
    end
  end

  defp maybe_errors([]), do: :ok
  defp maybe_errors(errors), do: {:error, errors}
end
