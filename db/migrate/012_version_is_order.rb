require 'redmine/i18n'

class VersionIsOrder < ActiveRecord::Migration

  def self.up
    add_column :versions, :is_order, :boolean, :default => false, :null => false

    Version.where("project_id = ? OR in_timesheet = ?", Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i), true).update_all(:is_order => true)
    field = VersionCustomField.create!(:name => "Is order", :field_format => 'bool', :is_filter => true, :is_required => true, :default_value => false, :description => "Used as an order in timesheets")
    val = Setting.plugin_redmine_app_timesheets
    val['field'] = field.id
    record = Setting.where(:name => "plugin_redmine_app_timesheets").first
    record.value = val
    record.save
  end

  def self.down
    remove_column :versions, :is_order
    VersionCustomField.where(:name => "Is order").destroy_all
  end

end