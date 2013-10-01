require 'redmine'

Rails.logger.info 'Starting Timesheet Application'

Redmine::Plugin.register :redmine_app_timesheet do
  name 'Redmine Timesheet Application'
  author 'Massimo Rossello'
  description 'Timesheet application for global app space'
  version '0.0.1'
  url 'https://github.com/maxrossello/redmine_app_timesheet.git'
  author_url 'https://github.com/maxrossello'
  requires_redmine :version_or_higher => '2.0.0'
  requires_redmine_plugin :redmine_app__space, '0.0.1'

end

# needs to be evaluated before /apps(/:tab)!
RedmineApp::Application.routes.prepend do
  get '/apps/timesheet', :controller => 'timesheet', :action => 'index'
end
