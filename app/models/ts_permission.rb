
class TsPermission < ActiveRecord::Base
  belongs_to :order, :class_name => 'WorkOrder', :foreign_key => 'order_id'
  belongs_to :version, :class_name => 'Version', :foreign_key => 'order_id'
  belongs_to :principal

  attr_accessible :order_id, :principal_id, :access, :is_primary

  # permissions
  NONE = 0
  VIEW = 1
  EDIT = 2
  ADMIN = 3

  validates_inclusion_of :access, :in => NONE..ADMIN

  scope :for_user, lambda {|*args|
    args = [User.current] unless args.present?
    users = args.dup

    # if visibility != NONE, users shall have an entry unless they are order admin
    # order admins must nevertheless be listed at least through some group
    args.each do |user|
      if user.admin? or user.groups.map(&:id).include?(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i)
        users << user.groups
      end
    end

    where(:principal_id => users.flatten).uniq
  }

  scope :for_group, lambda {|group|
    where(:principal_id => group)
  }

  scope :over, lambda {|order|
    where(:order_id => order)
  }

end