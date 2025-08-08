defmodule SaasTemplate.Repo do
  use Ecto.Repo,
    otp_app: :saas_template,
    adapter: Ecto.Adapters.Postgres
end
