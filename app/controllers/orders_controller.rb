class OrdersController < ApplicationController
  unloadable

  before_filter :require_login, :get_project

  helper ProjectsHelper
  helper CustomFieldsHelper

  def index
    unless User.is_app_visible?('order_mgmt')
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

    # handle ts order sharing with projects
    if !params[:share].nil? and !params[:id].nil?
      v = Version.find(params[:id])
      if v.project_id == @ts_project
        if params[:share] == "1"
          v.sharing = "system"
        else
          v.sharing = "none"
        end
        v.save
      end

      redirect_to url_for(params.except :share, :id)
    end

  end

  def disable
    order = Version.find(params[:id])
    order.in_timesheet = false
    order.save!
    redirect_to :action => 'index'
  end

  def enable
    order = Version.find(params[:id])
    order.in_timesheet = true
    order.save! if order.project_id != @ts_project or new_issue(order.name, order.id).save(:validate => false)

    redirect_to :action => 'index'
  end

  def create
    order = Project.find(@ts_project).versions.build
    if params[:version]
      attributes = params[:version].dup
      attributes.delete('sharing') unless attributes.nil? || order.allowed_sharings.include?(attributes['sharing'])
      order.safe_attributes = attributes
    end

    order.in_timesheet = 1

    saved = order.save if order.project_id == @ts_project and (i = new_issue(params[:version][:name])).save
    unless i.nil?
      if saved
        i.fixed_version_id = order.id
        i.save(:validate => false) # ok also with issue tracking off
      else
        # e.g. if duplicate order not saved
        i.delete
      end
    end

    if order.id.nil?
      redirect_to :controller => 'orders', :action => 'index'
    else
      redirect_to :controller => 'order_users', :action => 'index', :id => order.id
    end
  end

  def new
    @version = Version.new
  end

  private

  def new_issue(name, vid=nil)
    i = Issue.where(project_id: @ts_project, fixed_version_id: vid).first unless vid.nil?
    if i.nil?
      i = Issue.new
      i.tracker_id = Setting.plugin_redmine_app_timesheets['tracker']
      i.project_id = Setting.plugin_redmine_app_timesheets['project'].to_i
      i.subject = name
      i.status_id = IssueStatus.where(is_closed: 1).joins(workflows: :tracker).where('workflows.new_status_id = issue_statuses.id').where('workflows.tracker_id = trackers.id').where('trackers.id = ?', i.tracker_id).first.id rescue 1
      i.fixed_version_id = vid
      i.author = User.find(1) # admin
    end
    i
  end

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

end
