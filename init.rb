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

  unless Version.included_modules.include?(TimesheetsAppVersionPatch)
    Version.send(:include, TimesheetsAppVersionPatch)
  end

  unless Redmine::Helpers::TimeReport.included_modules.include?(TimesheetsAppTimeReportPatch)
    Redmine::Helpers::TimeReport.send(:include, TimesheetsAppTimeReportPatch)
  end
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
  post 'apps/order_mgmt/create', :controller => 'orders', :action => 'create'
  post 'apps/timesheets/save_weekly', :controller => 'timesheets', :action => 'save_weekly'
  delete 'apps/timesheets/delete_row', :controller => 'timesheets', :action => 'delete_row'
end

module Timesheet
  class Hooks < Redmine::Hook::ViewListener

    def view_layouts_base_html_head(context = { })
      stylesheet_link_tag 'timesheets.css', :plugin => 'redmine_app_timesheets'
    end

  end
end