defmodule SaasTemplateWeb.ChangelogHTML do
  use SaasTemplateWeb, :html

  embed_templates "changelog_html/*"
  embed_templates "../components/marketing/*"
end
