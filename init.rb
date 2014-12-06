require 'redmine'
require_dependency 'appspace_users_patch'

Time::DATE_FORMATS[:param_date] = "%Y-%m-%d"
Time::DATE_FORMATS[:week] = "%Y %b %e"
Time::DATE_FORMATS[:day] = "%a %e"

Rails.logger.info 'Starting Timesheets Application'

Rails.configuration.to_prepare do
  TimeEntry.class_eval do
    scope :for_user, lambda { |user| {:conditions => "#{TimeEntry.table_name}.user_id = #{user.id}"}}
    scope :spent_on, lambda { |date| {:conditions => ["#{TimeEntry.table_name}.spent_on = ?", date]}}
  end
end

Redmine::Plugin.register :redmine_app_timesheets do
  name 'Redmine Timesheets Application'
  author 'Massimo Rossello'
  description 'Timesheets application for global app space'
  version '1.4.9'
  url 'https://github.com/maxrossello/redmine_app_timesheets.git'
  author_url 'https://github.com/maxrossello'
  requires_redmine :version_or_higher => '2.0.0'
  requires_redmine_plugin :redmine_app__space, :version_or_higher => '0.0.2'

  settings(:default => {
      'project' => "",
      'public_versions' => true,
      'field' => 0
  },
  :partial => 'timesheets/settings'
  )

  require 'timesheets_app_issue_patch'
  require 'timesheets_app_project_patch'
  require 'timesheets_app_time_report_patch'
  require 'timesheets_app_custom_field_patch'
  require 'timesheets_app_version_patch'
  require 'timesheets_app_versions_controller_patch'

end


# needs to be evaluated before /apps(/:tab)!
RedmineApp::Application.routes.prepend do
  application 'timesheets', :to => 'timesheets#index', :via => [:get,:post]
  application 'order_mgmt', :to => 'orders#index', :via => :get

  put 'apps/order_mgmt/disable/:id', :controller => 'orders', :action => 'disable'
  put 'apps/order_mgmt/enable/:id', :controller => 'orders', :action => 'enable'
  post 'apps/order_mgmt/create', :controller => 'orders', :action => 'create'
  get 'apps/order_mgmt/new', :controller => 'orders', :action => 'new'

  get 'apps/order_users/:id', :controller => 'order_users', :action => 'index'
  get 'apps/order_users/:id/new', :controller => 'order_users', :action => 'new'
  get 'apps/order_users/:id/autocomplete_for_user', :controller => 'order_users', :action => 'autocomplete_for_user'
  get 'apps/order_users/:id/autocomplete_for_group', :controller => 'order_users', :action => 'autocomplete_for_group'
  post 'apps/order_users/:id/create', :controller => 'order_users', :action => 'create'
  delete 'apps/order_users/:order_id/:user_id/destroy', :controller => 'order_users', :action => 'destroy'
  post 'apps/order_users/activities', :controller => 'order_users', :action => 'activities'
  put 'apps/order_users/:id/set_perm/:role', :controller => 'order_users', :action => 'set_permission'

  get 'apps/timesheets/log_time', :controller => 'timesheets', :action => 'new'
  post 'apps/timesheets/add_entry', :controller => 'timesheets', :action => 'add_entry'
  post 'apps/timesheets/save_period', :controller => 'timesheets', :action => 'save_period'
  delete 'apps/timesheets/delete_row', :controller => 'timesheets', :action => 'delete_row'
  post 'apps/timesheets/copy_row', :controller => 'timesheets', :action => 'copy_row'
  delete 'apps/timesheets/remove_entry', :controller => 'timesheets', :action => 'remove_entry'
end

module Timesheet
  class Hooks < Redmine::Hook::ViewListener

    def view_layouts_base_html_head(context = { })
      stylesheet_link_tag 'timesheets.css', :plugin => 'redmine_app_timesheets'
    end

  end
end
