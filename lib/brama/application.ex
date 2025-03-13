defmodule Brama.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Connection Registry
      {Registry, keys: :unique, name: Brama.Registry.Connection},
      # Event Registry for pub/sub
      {Registry, keys: :duplicate, name: Brama.Registry.Event},
      # The connection manager
      Brama.ConnectionManager,
      # Event dispatcher
      Brama.EventDispatcher
    ]

    opts = [strategy: :one_for_one, name: Brama.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
