defmodule SaasTemplateWeb.SitemapController do
  use SaasTemplateWeb, :controller

  def index(conn, _params) do
    urls = []
    |> add_static_urls(conn)

    xml = generate_sitemap_xml(urls)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp add_static_urls(urls, _conn) do
    base_urls = [
      %{
        loc: url(~p"/"),
        changefreq: "weekly",
        priority: "1.0"
      },
      %{
        loc: url(~p"/terms"),
        changefreq: "yearly",
        priority: "0.3"
      },
      %{
        loc: url(~p"/privacy"),
        changefreq: "yearly",
        priority: "0.3"
      },
      %{
        loc: url(~p"/changelog"),
        changefreq: "monthly",
        priority: "0.7"
      }
    ]

    urls ++ base_urls
  end

  defp generate_sitemap_xml(urls) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "", &url_to_xml/1)}
    </urlset>
    """
  end

  defp url_to_xml(url) do
    """
      <url>
        <loc>#{url.loc}</loc>
    #{if url[:lastmod], do: "    <lastmod>#{url.lastmod}</lastmod>\n", else: ""}    <changefreq>#{url.changefreq}</changefreq>
        <priority>#{url.priority}</priority>
      </url>
    """
  end

end