################################################################################################
# Properties
################################################################################################
jquery_version = 'jquery-1.3.1.min.js'
app_name = @root.split('/').last
css_dir = "public/stylesheets"
sass_dir = "app/stylesheets"

################################################################################################
# Helper functions
################################################################################################
def prepend_to_file(file, text)
  run "echo \"#{text}\"|cat - #{file} > /tmp/out && mv /tmp/out #{file}"
end

def append_to_file(file, text)
  run "echo \"#{text}\" >> #{file}"
end

def remote_file(url, destination)
  run "curl -L #{url} > #{destination}"
end

################################################################################################
# Remove unwanted files
################################################################################################
run 'rm README'
run 'rm public/index.html'
run 'cp config/database.yml config/example_database.yml'
%w{ controls dragdrop effects prototype }.each { |f| run "rm public/javascripts/#{f}.js" }

################################################################################################
# Install plugins
################################################################################################
plugin 'haml-scaffold',             :git => 'git://github.com/norman/haml-scaffold.git'
plugin 'friendly_id',               :git => 'git://github.com/norman/friendly_id.git'

################################################################################################
# Configure and install gems
################################################################################################
with_options :source => 'http://gems.github.com' do |config|
  config.gem 'mbleigh-acts-as-taggable-on',  :lib => 'acts-as-taggable-on'
  config.gem 'tobi-delayed_job',             :lib => 'delayed_job'
  config.gem 'pluginaweek-state_machine',    :lib => 'state_machine'
  config.gem 'justinfrench-formtastic',      :lib => 'formtastic'
  config.gem 'mislav-will_paginate',         :lib => 'will_paginate'
  config.gem 'thoughtbot-paperclip',         :lib => 'paperclip'
  config.gem 'thoughtbot-clearance',         :lib => 'clearance'
  config.gem 'notahat-machinist',            :lib => 'machinist'
  config.gem 'cucumber',                     :lib => 'cucumber'
  config.gem 'thoughtbot-shoulda',           :lib => 'shoulda'
  config.gem 'webrat',                       :lib => 'webrat'
  config.gem 'mocha',                        :lib => 'mocha'
  config.gem 'chriseppstein-compass',        :lib => 'compass'
  config.gem 'haml',                         :lib => 'haml',                  :version => '>=2.2.0'
  config.gem 'pat-maddox-giternal',          :lib => 'giternal'
end
rake 'gems:install'
rake 'gems:unpack GEM=chriseppstein-compass'

################################################################################################
# Setup paging
################################################################################################
route "map.root :controller => 'pages', :action => 'show', :id => 'home'"
generate(:haml_scaffold, "page", "title:string", "body:text")
file 'app/models/page.rb', <<-RUBY
class Page < ActiveRecord::Base
  has_friendly_id :title, :use_slug => true
end
RUBY

################################################################################################
# Setup giternal
################################################################################################
GITERNALS = []
file 'config/giternal.yml', <<-YML
# Add any GIT externals here, don't forget to add the external to .gitignore so it doesn't get
# commited with the main project (although this should be added automagically).

#universal_helper:
#  repo: git@josh-nesbitt.net:universal_helper.git
#  path: vendor/plugins
  
YML

def add_giternal
  name = ask("\n>> Name? (E.g. sentinel)")
  repo = ask("\n>> Repo? (E.g. git@github.com:burt/sentinel.git)")
  append_to_file 'config/giternal.yml', <<-YML
#{name}:
  repo: #{repo}
  path: vendor/plugins
YML
  GITERNALS << "vendor/plugins/#{name}"
  add_giternal if yes?("\n>> Add another giternal? (y/n)")
end

if yes?("\n>> Add giternal? (y/n)")
  add_giternal
end

unless GITERNALS.empty?
  puts "\n>> GITERNALS: #{GITERNALS.join(', ')}"
  run 'giternal update'
end

################################################################################################
# Setup jquery
################################################################################################
remote_file "http://jqueryjs.googlecode.com/files/#{jquery_version}", "public/javascripts/#{jquery_version}"

################################################################################################
# Setup compass
################################################################################################
css_framework = "blueprint"

# build out compass command
compass_command = "compass --rails -f #{css_framework} . --css-dir=#{css_dir} --sass-dir=#{sass_dir} "

# Require compass during plugin loading
file 'vendor/plugins/compass/init.rb', <<-CONFIG
# This is here to make sure that the right version of sass gets loaded (haml 2.2) by the compass requires.
require 'compass'
CONFIG

# integrate it!
run 'haml --rails .'
run compass_command
run 'rm -rf public/stylesheets/sass'
append_to_file "config/compass.config", "output_style = :compact"

file "#{sass_dir}/screen.sass", <<-SASS
// This import applies a global reset to any page that imports this stylesheet.
@import blueprint/reset.sass
// To configure blueprint, edit the partials/base.sass file.
@import partials/base.sass
// Import all the default blueprint modules so that we can access their mixins.
@import blueprint
// Import the non-default scaffolding module.
@import blueprint/modules/scaffolding.sass

// To generate css equivalent to the blueprint css but with your configuration applied, uncomment:
+blueprint

SASS

file "#{sass_dir}/main.sass", <<-SASS
@import blueprint.sass
@import partials/base.sass

!a = #595241
!b = #B8AE9C
!c = #FFFFFF
!d = #ACCFCC
!e = #8A0917

body
  .container
    +container
#header
  +column(24)
  +last
  background-color = !b
  #logo
    +column(20)
  #session
    +column(4)
    +last
#nav
  +column(24)
  +last
  background-color = !e
#content
  +column(16)
#sidebar
  +column(8)
  +last
  background-color = !d
#footer
  +column(24)
  +last
  background-color = !b

SASS

################################################################################################
# Setup plugins
################################################################################################
generate :friendly_id
generate :acts_as_taggable_on_migration
generate :clearance
%w{ development test }.each { |e| prepend_to_file("config/environments/#{e}.rb", "HOST = 'localhost'") }
prepend_to_file("config/environment.rb", "DO_NOT_REPLY = 'donotreply@example.com'")

################################################################################################
# Create seed data
################################################################################################
file 'db/seeds.rb', <<-RUBY
require 'machinist/active_record'
require 'sham'
require 'faker'

Sham.define do
  name  { Faker::Name.name }
  email { Faker::Internet.email }
  title { Faker::Lorem.sentence }
  body  { Faker::Lorem.paragraph }
end

Page.blueprint do
  title
  body
end

Page.make(:title => "Home")

User.blueprint do
  email_confirmed { true }
end

RUBY

################################################################################################
# Create basic views
################################################################################################

file 'app/views/layouts/application.html.haml', <<-HAML
!!! XML
!!!
%html{ :'xml:lang' => "en", :lang => "en" }
  %head
    %title= "\#{controller.class.to_s}: \#{controller.action_name}"
    %meta{ :"http-equiv" => "Content-Type", :content => "text/html; charset=utf-8" }
    %link{ :rel => "shortcut icon", :href => "/favicon.ico" }
    = render :partial => 'shared/blueprint'
    = stylesheet_link_tag "main", :media => "screen"
    = javascript_include_tag "#{jquery_version}"
    = yield :head
  %body
    .container
      #header
        = render :partial => 'shared/header'
      #nav
        = render :partial => 'shared/nav'
      #content.prepend-top
        = render :partial => "shared/flash", :locals => { :flash => flash }
        = yield
      #sidebar
        = render :partial => 'shared/sidebar'
      #footer
        = render :partial => 'shared/footer'
HAML

file 'app/views/shared/_header.html.haml', <<-HAML
#logo
  %h1 #{app_name}
#session
  %ul
    - if signed_in?
      %li= "Signed in as: \#{current_user.email}"
      %li= link_to "Sign out", sign_out_path
    - else
      %li= link_to "Sign in", sign_in_path
      %li= link_to "Sign up", sign_up_path
HAML

file 'app/views/shared/_nav.html.haml', <<-HAML
Nav
HAML

file 'app/views/shared/_sidebar.html.haml', <<-HAML
Sidebar
HAML

file 'app/views/shared/_footer.html.haml', <<-HAML
Footer
HAML

file 'app/views/shared/_blueprint.html.haml', <<-HAML
= stylesheet_link_tag 'screen'
= stylesheet_link_tag 'print', :media => 'print'
/[if IE]
  = stylesheet_link_tag 'ie', :media => 'print'
HAML

file 'app/views/shared/_flash.html.haml', <<-HAML
- for name in [:notice, :warning, :message, :error, :failure, :success]
  - if flash[name]
    %div{:class => "flash \#{name}"}
      = h(flash[name])
HAML

################################################################################################
# Create users
################################################################################################

def add_user
  email = ask("\n>> Email?")
  password = ask("\n>> Password?")
  append_to_file "db/seeds.rb", "User.make(:email => '#{email}', :password => '#{password}', :password_confirmation => '#{password}')\n"
  add_user if yes?("\n>> Add another user? (y/n)")
end

if yes?("\n>> Add seed users? (y/n)")
  add_user
end

################################################################################################
# Complete installation
################################################################################################
rake "db:migrate"
rake "friendly_id:make_slugs MODEL=Page"
rake "db:seed"

################################################################################################
# Configure git
################################################################################################
if yes?("\n>> Create git repo? (y/n)")
  formatted_giternals = GITERNALS.join("\n")
  git :init
  file ".gitignore", <<-CONFIG
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
#{formatted_giternals}
CONFIG
  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  git :add => ".", :commit => "-m 'initial commit'"
end

puts "\n\nDone creating #{app_name}. Bye..."