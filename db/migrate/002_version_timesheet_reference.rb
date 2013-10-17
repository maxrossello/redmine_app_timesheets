class VersionTimesheetReference < ActiveRecord::Migration

  def self.up
    add_column :versions, :ts_reference, :integer, :default => 0, :null => false
  end

  def self.down
    remove_column :versions, :ts_reference
  end

end