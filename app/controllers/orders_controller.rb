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
      @versions = Version.scoped(:include => :project,
                 :conditions => "#{Project.table_name}.id = #{@ts_project}" +
                     " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
                     " #{Version.table_name}.sharing = 'system'" +
                     " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND #{Version.table_name}.sharing = 'tree')" +
                     " OR (#{Project.table_name}.lft < #{p.lft} AND #{Project.table_name}.rgt > #{p.rgt} AND #{Version.table_name}.sharing IN ('hierarchy', 'descendants'))" +
                     " OR (#{Project.table_name}.lft > #{p.lft} AND #{Project.table_name}.rgt < #{p.rgt} AND #{Version.table_name}.sharing = 'hierarchy')" +
                     "))").where(:in_timesheet => false).where("project_id != ?", @ts_project).all
      @orders = Version.where(:project_id => @ts_project)
    end
  end

  def disable
    order = Version.find(params[:id])
    order.in_timesheet = false if order.project_id != @ts_project
    order.save!
    redirect_to :action => 'index'
  end

  def enable
    order = Version.find(params[:id])
    # create a dup'ed version in the backing project and leave the original untouched
    neworder = order.dup
    neworder.project_id = Setting.plugin_redmine_app_timesheets['project'].to_i
    neworder.ts_reference = order.id
    neworder.save!
    order.in_timesheet = true if order.project_id != @ts_project
    order.ts_reference = neworder.id
    order.save!

    redirect_to :action => 'index'
  end

  def delete

  end
end