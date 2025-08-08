defmodule SaasTemplateWeb.LegalHTML do
  use SaasTemplateWeb, :html

  embed_templates "legal_html/*"
  embed_templates "../components/marketing/*"
end
