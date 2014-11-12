require_dependency 'appspace_users_patch'

class OrdersController < ApplicationController
  unloadable

  before_filter :require_login, :is_order_manager, :get_project

  helper ProjectsHelper
  helper CustomFieldsHelper

  def is_order_manager
    render_403 unless User.current.admin? or Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? or User.current.is_or_belongs_to? Group.find(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i)
  end

  def index
    unless User.is_app_enabled?('order_mgmt')
      render_404
    else
      # search is extended to all orders, irrespective of user visibility
      # only version name will be shown if not visible
      @orders = WorkOrder.all.group_by { |v| v.in_timesheet }

      # handle ts order sharing with projects
      if !params[:share].nil? and !params[:id].nil?
        v = WorkOrder.find(params[:id])
        if v.is_native?
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

  end

  def disable
    order = WorkOrder.find(params[:id])
    if (!order.is_native?)
      order.becomes(Version).custom_field_values.each do |cv|
        if cv.custom_field_id == Setting.plugin_redmine_app_timesheets["field"]
          cv.value = false
        end
      end
    end
    order.in_timesheet = false
    order.save!
    redirect_to :action => 'index'
  end

  def enable
    order = WorkOrder.find(params[:id])
    order.in_timesheet = true
    order.save!

    redirect_to :action => 'index'
  end

  def create
    order = Project.find(@ts_project).versions.build
    if params[:work_order]
      attributes = params[:work_order].dup
      attributes.delete('sharing') unless attributes.nil? || order.allowed_sharings.include?(attributes['sharing'])
      order.safe_attributes = attributes
    end

    order.in_timesheet = 1
    order.is_order = 1

    saved = order.save if order.project_id == @ts_project
    unless saved
      # e.g. if duplicate order not saved
      flash[:error] = l(:label_timesheet_order_not_saved)
    end

    if order.id.nil?
      redirect_to :controller => 'orders', :action => 'index'
    else
      redirect_to :controller => 'order_users', :action => 'index', :id => order.id
    end
  end

  def new
    @version = WorkOrder.new
  end

  private

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

end
