defmodule SaasTemplateWeb.RateLimit do
  use Hammer, backend: :ets
end
