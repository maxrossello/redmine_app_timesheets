require 'redmine/i18n'

class VersionIsOrder < ActiveRecord::Migration

  def self.up
    add_column :versions, :is_order, :boolean, :default => false, :null => false

    project_id = (Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i) rescue nil)
    if project_id != nil
      Version.where("project_id = ? OR in_timesheet = ?", project_id, true).update_all(:is_order => true)
    end

    if Redmine::VERSION::MAJOR < 2 || Redmine::VERSION::MINOR < 5
      field = VersionCustomField.create!(:name => "Is order", :field_format => 'bool', :is_filter => true, :is_required => true, :default_value => false)
    else
      field = VersionCustomField.create!(:name => "Is order", :field_format => 'bool', :is_filter => true, :is_required => true, :default_value => false, :description => "Used as an order in timesheets")
    end

    val = Setting.plugin_redmine_app_timesheets
    val['field'] = field.id.to_s
    record = Setting.where(:name => "plugin_redmine_app_timesheets").first
    record = Setting.new :name => "plugin_redmine_app_timesheets" if record.nil?
    record.value = val
    record.save :validate => false
  end

  def self.down
    remove_column :versions, :is_order
    VersionCustomField.find(Setting.plugin_redmine_app_timesheets["field"].to_i).delete
  end

end
