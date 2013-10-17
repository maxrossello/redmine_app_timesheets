class VersionInTimesheet < ActiveRecord::Migration

  def self.up
    add_column :versions, :in_timesheet, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :versions, :in_timesheet
  end

end