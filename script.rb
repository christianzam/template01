run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'rails', '6.1.6
    gem 'autoprefixer-rails', '10.2.5'
    gem 'devise'
    gem 'font-awesome-sass'
    gem 'httparty'
    gem 'pg_search'
    gem 'simple_form'  
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  RUBY
end

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

# Assets
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
run 'curl -L https://github.com/lewagon/rails-stylesheets/archive/master.zip > stylesheets.zip'
run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/rails-stylesheets-master app/assets/stylesheets'

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Flashes
########################################
file 'app/views/shared/_flash.html.erb', <<~HTML
<% if flash[:notice]%>
  <div class="alert alert-info mt-4" role="alert">
    <%= flash[:notice] %>
  </div>
<% end %>

<% if flash[:alert] %>
  <div class="alert alert-warning mt-4" role="alert">
    <%= flash[:alert] %>
  </div>
<% end %>
HTML

# Navbar
########################################
file 'app/views/shared/_navbar.html.erb', <<~HTML
<nav class="navbar navbar-expand-lg navbar-light bg-light">
  <div class="container-fluid">
    <%= link_to "Home", root_path, class: "navbar-brand" %>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarSupportedContent">
      <ul class="navbar-nav me-auto mb-2 mb-lg-0">
        <li class="nav-item">
          <%= link_to "Home", root_path, class: "nav-link" %>
        </li>
        <li class="nav-item">
          <%= link_to "Home", root_path, class: "nav-link" %>
          <%# <a class="nav-link" href="/about">About US</a> THIS IS ANOTHER WAY BUT WRONG FOR RAILS%>
        </li>
      </ul>
      <ul class=" navbar-nav ms-auto mb-2 mb-lg-0">
        <% if current_user%>
        <li class="nav-item">
          <%= link_to current_user.email, edit_user_password_path, class: 'nav-link' %>
        </li>
        <%= button_to 'Logout', destroy_user_session_path, method: :delete, class: 'btn btn-outline-secondary' %>
        <% else %>
          <li class="nav-item">
            <%= link_to 'Sign Up', new_user_registration_path, class: 'nav-link' %>
          </li>
          <li class="nav-item">
            <%= link_to 'Log In', new_user_session_path, class: 'nav-link' %>
          </li>
        <% end %>
      </ul>
    </div>
  </div>
</nav>
HTML

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
  <%= render 'shared/navbar' %>
  <div class="container">
    <%= render partial: 'shared/flash' %>
    <%= yield %>
  </div>
  HTML
end

inject_into_file 'app/views/layouts/application.html.erb', after: '<head>' do
  <<-HTML

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js" integrity="sha384-ka7Sk0Gln4gmtz2MlQnikT1wXgYsOg+OMhuP+IlRH9sENBO0LRn5q+8nbTov4+1p" crossorigin="anonymous"></script>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-1BmE4kWBq78iYhFldvKuhfTAU6auU8tT94WrHftjDbrCEXSU1oBoqyl2QvZ6jIW3" crossorigin="anonymous">

  HTML
end

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators
########################################
# run bundle install
########################################

run 'bundle install'

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install', '--bootstrap')
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  rails_command 'generate devise:install'

  rails_command 'generate devise User'

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'

  rails_command 'generate devise:views'

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Webpacker / Yarn
  ########################################
  run 'yarn add popper.js jquery bootstrap@4.6'
  append_file 'app/javascript/application.js', <<~JS


    // ----------------------------------------------------
    // ABOVE IS RAILS DEFAULT CONFIGURATION
    // WRITE YOUR OWN JS STARTING FROM HERE 👇
    // ----------------------------------------------------

    // External imports
    import "bootstrap";

    // Internal imports, e.g:
    // import { initSelect2 } from '../components/init_select2';

    document.addEventListener('turbolinks:load', () => {
      // Call your functions here, e.g:
      // initSelect2();
    });
  JS

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit devise, navbar and userModel'"

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')

  # LAST MIGRATION
  ########################################
  rails_command 'db:drop db:create db:migrate'
end
