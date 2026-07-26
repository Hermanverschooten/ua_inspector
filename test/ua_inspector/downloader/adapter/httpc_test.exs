defmodule UAInspector.Downloader.Adapter.HttpcTest do
  use ExUnit.Case, async: true

  alias UAInspector.Downloader.Adapter.Httpc

  test "errors returned from adapter" do
    assert {:error, {:no_scheme}} = Httpc.read_remote("invalid")
  end

  test "requires HTTP 200 responses for success" do
    httpd_opts = [
      port: 0,
      server_name: ~c"ua_inspector_httpc_test",
      server_root: String.to_charlist(__DIR__),
      document_root: String.to_charlist(__DIR__)
    ]

    {:ok, httpd_pid} = :inets.start(:httpd, httpd_opts)

    location = "http://localhost:#{:httpd.info(httpd_pid)[:port]}/--does-not-exist--"

    assert {:error, {:status, 404, ^location}} = Httpc.read_remote(location)

    :inets.stop(:httpd, httpd_pid)
  end

  test "reads remote contents" do
    httpd_opts = [
      port: 0,
      server_name: ~c"ua_inspector_httpc_read_test",
      server_root: String.to_charlist(__DIR__),
      document_root: String.to_charlist(__DIR__)
    ]

    {:ok, httpd_pid} = :inets.start(:httpd, httpd_opts)

    location = "http://localhost:#{:httpd.info(httpd_pid)[:port]}/httpc_test.exs"

    assert {:ok, contents} = Httpc.read_remote(location)
    assert String.contains?(contents, "UAInspector.Downloader.Adapter.HttpcTest")

    :inets.stop(:httpd, httpd_pid)
  end
end
