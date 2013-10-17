require 'redmine'
require_dependency 'appspace_users_patch'

Rails.logger.info 'Starting Timesheets Application'

Redmine::Plugin.register :redmine_app_timesheets do
  name 'Redmine Timesheets Application'
  author 'Massimo Rossello'
  description 'Timesheets application for global app space'
  version '0.0.1'
  url 'https://github.com/maxrossello/redmine_app_timesheets.git'
  author_url 'https://github.com/maxrossello'
  requires_redmine :version_or_higher => '2.0.0'
  requires_redmine_plugin :redmine_app__space, '0.0.1'

  settings(:default => {
      'project' => "",
      'admin_group' => "",
      'tracker' => "",
  },
  :partial => 'timesheets/settings'
  )
end

# needs to be evaluated before /apps(/:tab)!
RedmineApp::Application.routes.prepend do
  application 'timesheets', :to => 'timesheets#index', :via => :get
  application 'order_mgmt', :to => 'orders#index', :via => :get,
              :if => lambda {
                |user| User.in_group(Setting.plugin_redmine_app_timesheets['admin_group']).include?(user)
              }

  put 'apps/order_mgmt/disable/:id', :controller => 'orders', :action => 'disable'
  put 'apps/order_mgmt/enable/:id', :controller => 'orders', :action => 'enable'
  delete 'apps/order_mgmt/delete/:id', :controller => 'orders', :action => 'delete'
end
