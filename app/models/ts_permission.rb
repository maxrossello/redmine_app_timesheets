
class TsPermission < ActiveRecord::Base
  belongs_to :order, :class_name => 'WorkOrder', :foreign_key => 'order_id'
  belongs_to :version, :class_name => 'Version', :foreign_key => 'order_id'
  belongs_to :principal

  attr_accessible :order_id, :principal_id, :access, :is_primary

  # permissions
  FORBIDDEN = -1
  NONE = 0  # should be better named "OWN"
  VIEW = 1
  EDIT = 2
  ADMIN = 3

  validates_inclusion_of :access, :in => NONE..ADMIN

  scope :for_user, lambda {|*args|
    args = [User.current] unless args.present?
    users = args.dup

    # order and system admins must nevertheless be listed at least through some group
    args.each do |user|
      #if user.admin? or user.groups.map(&:id).include?(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i)
        users << user.groups
      #end
    end

    where(:is_primary => true, :principal_id => users.flatten).uniq
  }

  scope :for_group, lambda {|group|
    where(:principal_id => group)
  }

  scope :over, lambda {|order|
    where(:order_id => order)
  }

  def self.permission(user,version)
    return ADMIN if user.admin? or User.in_group(Setting.plugin_redmine_app__space['auth_group']['order_mgmt']).include?(user)

    perm = TsPermission.over(version).for_user(user).all

    if perm.empty?
      return FORBIDDEN
    else
      return perm.first.access
    end

  end
end