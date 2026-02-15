defmodule Mix.Tasks.SaasTemplate.Gen.OauthGoogle do
  @moduledoc """
  Installs Google OAuth authentication for the SaaS template using Igniter.

  This task:
  - Adds ueberauth_google dependency to mix.exs
  - Adds Ueberauth configuration to config.exs
  - Updates the User schema with OAuth fields
  - Adds OAuth registration functionality to Accounts context
  - Creates GoogleAuthController for handling OAuth flow
  - Updates router with OAuth routes
  - Adds Google login button to login page
  - Creates database migration for OAuth fields

      $ mix saas_template.gen.oauth_google

  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {opts, _} = OptionParser.parse!(igniter.args.argv, switches: [yes: :boolean])

    igniter =
      igniter
      |> add_ueberauth_google_dependency()
      |> add_ueberauth_config()
      |> update_user_schema()
      |> update_accounts_context()
      |> create_google_auth_controller()
      |> update_router()
      |> add_oauth_button_component()
      |> create_oauth_migration()
      |> update_env_example()

    if opts[:yes] do
      igniter
    else
      print_completion_notice(igniter)
    end
  end

  defp add_ueberauth_google_dependency(igniter) do
    Igniter.update_file(igniter, "mix.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "{:ueberauth_google,") do
        # Dependency already exists
        source
      else
        # Add ueberauth_google dependency after fun_with_flags_ui
        updated_content =
          String.replace(
            content,
            ~r/(\{:fun_with_flags_ui, "~> 1\.1"\},)/,
            "\\1\n      # Social Auth Google\n      {:ueberauth_google, \"~> 0.10\"},"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp add_ueberauth_config(igniter) do
    config_content = """
    config :ueberauth, Ueberauth,
      providers: [
        google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
      ]

    config :ueberauth, Ueberauth.Strategy.Google.OAuth,
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
    """

    Igniter.update_file(igniter, "config/config.exs", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "config :ueberauth, Ueberauth") do
        # Config already exists
        source
      else
        # Add Ueberauth config before the import_config line
        updated_content =
          String.replace(
            content,
            ~r/(# Import environment specific config\. This must remain at the bottom)/,
            "\n#{config_content}\n\\1"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp update_user_schema(igniter) do
    igniter
    |> Igniter.update_file("lib/saas_template/accounts/user.ex", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "field :is_oauth_user") do
        # OAuth fields already exist
        source
      else
        # Add OAuth fields after authenticated_at field
        updated_content =
          String.replace(
            content,
            ~r/(field :authenticated_at, :utc_datetime, virtual: true)/,
            "\\1\n\n    field :is_oauth_user, :boolean, default: false\n    field :oauth_provider, :string"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
    |> Igniter.update_file("lib/saas_template/accounts/user.ex", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "def oauth_registration_changeset") do
        # OAuth changeset function already exists
        source
      else
        # Add oauth_registration_changeset function after email_changeset
        changeset_function = """

  @doc \"\"\"\n  A user changeset for OAuth registration.\n\n  It validates the email and oauth_provider fields, sets is_oauth_user to true,\n  and automatically confirms the email (OAuth emails are pre-verified).\n  \"\"\"\n  def oauth_registration_changeset(user, attrs, opts \\\\\\\\ []) do\n    user\n    |> cast(attrs, [:email, :oauth_provider])\n    |> validate_required([:email, :oauth_provider])\n    |> validate_email(opts)\n    |> put_change(:is_oauth_user, true)\n    |> put_change(:confirmed_at, DateTime.utc_now())\n |> DateTime.truncate(:second))\n end
        """
        
        updated_content =
          String.replace(
            content,
            ~r/(def email_changeset\(user, attrs, opts \\\\ \[\]\) do[\s\S]*?end)/,
            "\\1#{changeset_function}"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp update_accounts_context(igniter) do
    Igniter.update_file(igniter, "lib/saas_template/accounts.ex", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "def register_oauth_user") do
        # OAuth registration function already exists
        source
      else
        # Add register_oauth_user function after register_user
        updated_content =
          String.replace(
            content,
            ~r/(def register_user\(attrs\) do[\s\S]*?\n  end)/,
            "\\1\n\n  def register_oauth_user(attrs) do\n    %User{}\n    |> User.oauth_registration_changeset(attrs)\n    |> Repo.insert()\n  end"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp create_google_auth_controller(igniter) do
    controller_content = """
    defmodule SaasTemplateWeb.GoogleAuthController do
      use SaasTemplateWeb, :controller

      alias SaasTemplate.Accounts
      alias SaasTemplateWeb.UserAuth

      require Logger

      plug Ueberauth

      def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
        Logger.warning("OAuth authentication failed: \#{inspect(failure.errors)}")

        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: ~p"/users/log_in")
      end

      def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
        email = auth.info.email

        case Accounts.get_user_by_email(email) do
          nil ->
            # User does not exist, so create a new user
            user_params = %{
              email: email,
              oauth_provider: "google"
            }

            case Accounts.register_oauth_user(user_params) do
              {:ok, user} ->
                UserAuth.log_in_user(conn, user)

              {:error, changeset} ->
                Logger.error("Failed to create user \#{inspect(changeset)}.")

                conn
                |> put_flash(:error, "Failed to create user.")
                |> redirect(to: ~p"/")
            end

          user ->
            # User exists, update session or other details if necessary
            UserAuth.log_in_user(conn, user)
        end
      end
    end
    """

    Igniter.create_new_file(
      igniter,
      "lib/saas_template_web/controllers/google_auth_controller.ex",
      controller_content
    )
  end

  defp update_router(igniter) do
    Igniter.update_file(igniter, "lib/saas_template_web/router.ex", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "scope \"/auth\"") do
        # OAuth routes already exist
        source
      else
        # Add OAuth routes after the log-out route
        updated_content =
          String.replace(
            content,
            ~r/(delete "\/users\/log-out", UserSessionController, :delete)/,
            "\\1\n\n    scope \"/auth\" do\n      get \"/google\", GoogleAuthController, :request\n      get \"/google/callback\", GoogleAuthController, :callback\n    end"
          )

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp add_oauth_button_component(igniter) do
    component_content = ~s"""
    @doc \"\"\"
    Renders an OAuth provider login button.

    ## Examples

        <.oauth_button provider="google">
          Continue with Google
        </.oauth_button>

        <.oauth_button provider="google" class="btn-lg">
          <.icon name="hero-lock-closed" /> Sign in with Google
        </.oauth_button>
    \"\"\"
    attr :provider, :string, required: true
    attr :class, :string, default: nil
    attr :rest, :global, include: ~w(disabled)

    slot :inner_block, required: true

    def oauth_button(assigns) do
      ~H\"\"\"
      <.link href={~p"/auth/\#{@provider}"} class={["btn btn-outline w-full gap-2", @class]} {@rest}>
        \<%= render_slot(@inner_block) %>
      </.link>
      \"\"\"
    end

    """

    Igniter.update_file(
      igniter,
      "lib/saas_template_web/components/core_components.ex",
      fn source ->
        content = Rewrite.Source.get(source, :content)

        if String.contains?(content, "def oauth_button") do
          # OAuth button component already exists
          source
        else
          # Add oauth_button component before the icon/1 component
          updated_content =
            String.replace(
              content,
              ~r/(  @doc \"""\n  Renders a \[Heroicon\])/,
              "#{component_content}\\1"
            )

          Rewrite.Source.update(source, :content, updated_content)
        end
      end
    )
  end

  defp create_oauth_migration(igniter) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d%H%M%S")

    migration_content = """
    defmodule SaasTemplate.Repo.Migrations.AddOauthUser do
      use Ecto.Migration

      def up do
        alter table(:users) do
          add :is_oauth_user, :boolean, default: false
          add :oauth_provider, :string, null: true
          modify :hashed_password, :string, null: true
        end
      end

      def down do
        alter table(:users) do
          remove :is_oauth_user
          remove :oauth_provider
          modify :hashed_password, :string, null: false
        end
      end
    end
    """

    Igniter.create_new_file(
      igniter,
      "priv/repo/migrations/#{timestamp}_add_oauth_user.exs",
      migration_content
    )
  end

  defp update_env_example(igniter) do
    Igniter.update_file(igniter, ".env.example", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, "GOOGLE_CLIENT_ID") do
        # Google OAuth env vars already exist
        source
      else
        # Add Google OAuth environment variables at the top
        google_env_vars = """
        # Google OAuth Configuration
        GOOGLE_CLIENT_ID=your_google_client_id
        GOOGLE_CLIENT_SECRET=your_google_client_secret

        """

        updated_content =
          if String.trim(content) == "" do
            google_env_vars
          else
            google_env_vars <> content
          end

        Rewrite.Source.update(source, :content, updated_content)
      end
    end)
  end

  defp print_completion_notice(igniter) do
    completion_message = """

    ## Google OAuth Integration Complete! 🔐

    Google OAuth authentication has been successfully integrated into your SaaS template.

    ### Dependencies Added:
    - ueberauth_google (~> 0.10) for Google OAuth strategy

    ### Configuration Added:
    - Ueberauth configuration in config/config.exs
    - Google OAuth strategy with email and profile scopes
    - Environment variables for Google OAuth credentials

    ### Code Updates:
    - User schema updated with OAuth fields (is_oauth_user, oauth_provider)
    - OAuth users automatically confirmed (emails pre-verified by Google)
    - Accounts context extended with register_oauth_user/1 function
    - GoogleAuthController created with OAuth success/failure handling
    - Router updated with OAuth routes (/auth/google, /auth/google/callback)
    - OAuth button component added to core_components.ex

    ### Files Created:
    - lib/saas_template_web/controllers/google_auth_controller.ex
    - Database migration for OAuth user fields

    ### Files Updated:
    - .env.example with Google OAuth environment variables

    ### ✅ Manual Integration (30 seconds):

    Add the Google login button to your login page:

    1. Open: lib/saas_template_web/live/user_live/login.ex

    2. Add after the password form (around line 94):

        <div class="divider text-sm">OR</div>

        <.oauth_button provider="google">
          Continue with Google
        </.oauth_button>

    3. (Optional) Add the same to your registration page:
       lib/saas_template_web/live/user_live/registration.ex

    ### Next Steps:

    1. Set up Google OAuth credentials:
       - Visit https://console.developers.google.com/
       - Create a new project or select existing one
       - Enable Google+ API
       - Create OAuth 2.0 credentials
       - Set authorized redirect URI: http://localhost:4000/auth/google/callback

    2. Configure environment variables in .env:
       - GOOGLE_CLIENT_ID=your_actual_google_client_id
       - GOOGLE_CLIENT_SECRET=your_actual_google_client_secret

    3. Run the database migration:
       mix ecto.migrate

    4. Test the OAuth flow:
       mix phx.server
       # Navigate to /users/log_in and test Google login

    5. Update production redirect URI when deploying:
       https://yourdomain.com/auth/google/callback

    ### OAuth Flow:
    - Users click "Continue with Google" button
    - New users automatically registered with confirmed email
    - Existing users with matching email are logged in
    - OAuth failures handled gracefully with error messages

    🎉 Your app now supports stable, maintainable Google OAuth authentication!
    """

    Igniter.add_notice(igniter, completion_message)
  end
end
