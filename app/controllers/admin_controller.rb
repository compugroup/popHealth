require 'import_archive_job'
require 'fileutils'

class AdminController < ApplicationController
  include LogsHelper

  before_filter :authenticate_user!
  before_filter :validate_authorization!

  def patients
    log_admin_controller_call LogAction::VIEW, "View patient control panel"
    @patient_count = Record.count
    @query_cache_count = HealthDataStandards::CQM::QueryCache.count
    @patient_cache_count = PatientCache.count
    @provider_count = Provider.ne('cda_identifiers.root' => "Organization").count
    @practice_count = Practice.count
    @practices = Practice.asc(:name).map {|org| [org.name, org.id]}
  end

  def user_profile
    @user = User.find(params[:id])
    log_admin_controller_call LogAction::VIEW, "Get user profie"
    @practices = Practice.asc(:name).map {|org| [org.name, org.id]}
    @practice_pvs = Provider.by_npi(@user.npi).map {|pv| [pv.parent.practice.name + " - " + pv.full_name, pv.id]}
  end

  def set_user_practice
    @user = User.find(params[:user])
    log_admin_controller_call LogAction::UPDATE, "Set user practice"
    @user.practice = (params[:practice].present?) ? Practice.find(params[:practice]) : nil
    @user.save
    redirect_to action: 'user_profile', :id => params[:user]
  end

  def set_user_practice_provider
    @user = User.find(params[:user])
    log_admin_controller_call LogAction::UPDATE, "Set user practice provider"
    @user.provider_id = (params[:provider].present?)? Provider.find(params[:provider]).id : nil
    @user.save
    redirect_to action: 'user_profile', :id => params[:user]
  end

  def remove_patients
    log_admin_controller_call LogAction::DELETE, "Remove all #{Record.all.length} patients", true
    Record.delete_all
    redirect_to action: 'patients'
  end

  def remove_caches
    log_admin_controller_call LogAction::DELETE, "Remove caches"
    HealthDataStandards::CQM::QueryCache.delete_all
    PatientCache.delete_all
    Mongoid.default_session["rollup_buffer"].drop()
    redirect_to action: 'patients'
  end

  def remove_providers
    log_admin_controller_call LogAction::DELETE, "Remove all providers"
    Provider.ne('cda_identifiers.root' => "Organization").delete
    
    Team.update_all(providers: [])
    
    redirect_to action: 'patients'
  end

  def upload_patients
    log_admin_controller_call LogAction::ADD, "Upload patients", true
    file = params[:file]
    practice = params[:practice]
    
    FileUtils.mkdir_p(File.join(Dir.pwd, "tmp/import"))
    file_location = File.join(Dir.pwd, "tmp/import")
    file_name = "patient_upload" + Time.now.to_i.to_s + rand(1000).to_s

    temp_file = File.new(file_location + "/" + file_name, "w")

    File.open(temp_file.path, "wb") { |f| f.write(file.read) }

    Delayed::Job.enqueue(ImportArchiveJob.new({'practice' => practice, 'file' => temp_file,'user' => current_user}),:queue=>:patient_import)
    redirect_to action: 'patients'
  end

  def upload_providers
    log_admin_controller_call LogAction::ADD, "Upload providers"
    file = params[:file]
    FileUtils.mkdir_p(File.join(Dir.pwd, "tmp/import"))
    file_location = File.join(Dir.pwd, "tmp/import")
    file_name = "provider_upload" + Time.now.to_i.to_s + rand(1000).to_s

    temp_file = File.new(file_location + "/" + file_name, "w")

    File.open(temp_file.path, "wb") { |f| f.write(file.read) }

    provider_tree = ProviderTreeImporter.new(File.open(temp_file))
    provider_tree.load_providers(provider_tree.sub_providers)

    redirect_to action: 'patients'
  end

  def users
    log_admin_controller_call LogAction::VIEW, "View all users"

    @users = User.all.ordered_by_username
    @practices = Practice.asc(:name).map {|org| [org.name, org.id]}
    unless APP_CONFIG['use_opml_structure']
      @practice_providers = Provider.ne('cda_identifiers.root' => "Organization").asc(:given_name).map {|pv| [pv.full_name, pv.id]}
    end
  end

  def promote
    toggle_privilidges(params[:username], params[:role], :promote)
    log_admin_controller_call LogAction::UPDATE, "Promote user"
  end

  def demote
    toggle_privilidges(params[:username], params[:role], :demote)
    log_admin_controller_call LogAction::UPDATE, "Demote user"
  end

  def disable
    @user = User.by_username(params[:username]);
    log_admin_controller_call LogAction::UPDATE, "Disable user"
    disabled = params[:disabled].to_i == 1
    if @user
      @user.update_attribute(:disabled, disabled)
      if (disabled)
        render :text => "<a href=\"#\" class=\"disable\" data-username=\"#{CGI::escapeHTML(@user.username)}\">disabled</span>"
      else
        render :text => "<a href=\"#\" class=\"enable\" data-username=\"#{CGI::escapeHTML(@user.username)}\">enabled</span>"
      end
    else
      render :text => "User not found"
    end
  end

  def approve
    @user = User.where(:username => params[:username]).first
    log_admin_controller_call LogAction::UPDATE, "Approve user"
    if @user
      @user.update_attribute(:approved, true)
      render :text => "true"
    else
      render :text => "User not found"
    end
  end

  def update_npi
    @user = User.by_username(params[:username]);
    log_admin_controller_call LogAction::UPDATE, "Update NPI for user"
    @user.update_attribute(:npi, params[:npi]);
    render :text => "true"
  end

  def delete_user
    @user = User.find(params[:id])
    log_admin_controller_call LogAction::DELETE, "Delete user"
    if User.count == 1
      redirect_to :action => :users, notice: "Cannot remove sole user"
    elsif @user.admin? 
      redirect_to :action => :users, notice: "Cannot remove administrator"
    else
      @user.destroy
      redirect_to :action => :users
    end
  end

  private

  def toggle_privilidges(username, role, direction)
    @user = User.by_username username

    if @user
      if direction == :promote
        @user.update_attribute(role, true)
        render :text => "Yes - <a href=\"#\" class=\"demote\" data-role=\"#{role}\" data-username=\"#{CGI::escapeHTML(username)}\">revoke</a>"
      else
        @user.update_attribute(role, false)
        render :text => "No - <a href=\"#\" class=\"promote\" data-role=\"#{role}\" data-username=\"#{CGI::escapeHTML(username)}\">grant</a>"
      end
    else
      render :text => "User not found"
    end
  end

  def validate_authorization!
    authorize! :admin, :users
  end
end
