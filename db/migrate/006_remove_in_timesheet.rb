# use just the time entry's fixed_version_id to understand it's in timesheet

class RemoveInTimesheet < ActiveRecord::Migration
  def up
    remove_column :time_entries, :in_timesheet
    rename_column :time_entries, :fixed_version_id, :order_id
  end

  def down
    add_column :time_entries, :in_timesheet, :boolean, :default => false, :null => false
    rename_column :time_entries, :order_id, :fixed_version_id
  end
end
