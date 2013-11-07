class OrdersController < ApplicationController
  unloadable

  before_filter :require_login

  helper ProjectsHelper

  def index
    unless User.in_group(Setting.plugin_redmine_app_timesheets["admin_group"]).include?(User.current)
      render_404
    else
      @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
      p = Project.find(@ts_project)
      r = p.root? ? p : p.root
      # search is extended to all shared versions reachable by the backing project, irrespective of user visibility
      # only version name will be shown if not visible
      @orders = Version.scoped(:include => :project,
                 :conditions => "#{Project.table_name}.id = #{@ts_project}" +
                     " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
                     " #{Version.table_name}.sharing = 'system'" +
                     " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND #{Version.table_name}.sharing = 'tree')" +
                     " OR (#{Project.table_name}.lft < #{p.lft} AND #{Project.table_name}.rgt > #{p.rgt} AND #{Version.table_name}.sharing IN ('hierarchy', 'descendants'))" +
                     " OR (#{Project.table_name}.lft > #{p.lft} AND #{Project.table_name}.rgt < #{p.rgt} AND #{Version.table_name}.sharing = 'hierarchy')" +
                     "))").all.group_by { |v| v.in_timesheet }
    end
  end

  def disable
    order = Version.find(params[:id])
    order.in_timesheet = false
    order.save!
    redirect_to :action => 'index'
  end

  def enable
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i

    order = Version.find(params[:id])
    order.in_timesheet = true
    order.save! if order.project_id != @ts_project or new_issue(order.name, order.id).save

    redirect_to :action => 'index'
  end

  def create
    order = Version.new(:name => params[:name],
                :project_id => Setting.plugin_redmine_app_timesheets['project'].to_i,
                :in_timesheet => true)

    order.save! if order.project_id != @ts_project or (i = new_issue(params[:name])).save
    unless i.nil?
      i.fixed_version_id = order.id
      i.save!
    end

    redirect_to :action => 'index'
  end

  private

  def new_issue(name, vid=nil)
    i = Issue.where(project_id: @ts_project, fixed_version_id: vid).first unless vid.nil?
    if i.nil?
      i = Issue.new
      i.tracker_id = Setting.plugin_redmine_app_timesheets['tracker']
      i.project_id = Setting.plugin_redmine_app_timesheets['project'].to_i
      i.subject = name
      i.status_id = IssueStatus.where(is_closed: 1).joins(workflows: :tracker).where('workflows.new_status_id = issue_statuses.id').where('workflows.tracker_id = trackers.id').where('trackers.id = ?', i.tracker_id).first.id
      i.fixed_version_id = vid
      i.author = User.find(1) # admin
    end
    i
  end

end
