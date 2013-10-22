class TimeEntriesInTimesheet < ActiveRecord::Migration

  def self.up
    add_column :time_entries, :in_timesheet, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :time_entries, :in_timesheet
  end

end