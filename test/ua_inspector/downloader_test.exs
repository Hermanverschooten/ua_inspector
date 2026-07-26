defmodule UAInspector.DownloaderTest do
  use ExUnit.Case, async: false

  alias UAInspector.Downloader

  defmodule FailingAdapter do
    @moduledoc false

    @behaviour UAInspector.Downloader.Adapter

    @impl UAInspector.Downloader.Adapter
    def read_remote(location), do: {:error, {:status, 404, location}}
  end

  @pathname Path.join(System.tmp_dir!(), "ua_inspector_downloader_test")

  setup do
    database_path = Application.get_env(:ua_inspector, :database_path)
    downloader_adapter = Application.get_env(:ua_inspector, :downloader_adapter)

    Application.put_env(:ua_inspector, :database_path, @pathname)
    Application.put_env(:ua_inspector, :downloader_adapter, FailingAdapter)

    on_exit(fn ->
      restore_env(:database_path, database_path)
      restore_env(:downloader_adapter, downloader_adapter)

      File.rm_rf!(@pathname)
    end)
  end

  defp restore_env(key, nil), do: Application.delete_env(:ua_inspector, key)
  defp restore_env(key, value), do: Application.put_env(:ua_inspector, key, value)

  test "download failures are returned and not raised" do
    assert {:error, [_ | _] = errors} = Downloader.download()

    assert Enum.all?(errors, fn
             {remote, {:status, 404, remote}} when is_binary(remote) -> true
             _ -> false
           end)
  end

  test "download failures are collected for every type" do
    assert {:error, [_ | _]} = Downloader.download(:client_hints)
    assert {:error, [_ | _]} = Downloader.download(:databases)
    assert {:error, [_ | _]} = Downloader.download(:short_code_maps)
  end

  test "failed short code map downloads are not converted" do
    assert {:error, [_ | _]} = Downloader.download(:short_code_maps)

    assert [] = Path.wildcard(Path.join(@pathname, "*.tmp"))
    assert [] = Path.wildcard(Path.join(@pathname, "short_codes.*"))
  end
end
