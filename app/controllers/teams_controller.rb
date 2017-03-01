class TeamsController < ApplicationController
  include LogsHelper

  before_filter :authenticate_user!

  before_action :set_team, only: [:show, :edit, :update, :destroy]
  authorize_resource
  # GET /teams
  def index
    log_controller_call LogAction::VIEW, "View all teams"
    @teams = @current_user.teams
    validate_authorization!(@teams)
  end

  # GET /teams/1
  def show
    log_controller_call LogAction::VIEW, "View team"
    @providers = @team.providers.map do |id| 
      provider = Provider.find(id)
      provider unless cannot? :read, provider 
    end
  end

  # GET /teams/new
  def new
    log_controller_call LogAction::VIEW, "View page to create new team"
    if current_user.admin? || APP_CONFIG['use_opml_structure']
      @providers = Provider.all
    else
      @providers = Provider.where(parent_id: current_user.try(:practice).try(:provider_id))
    end
  end
  
  # POST 
  def create
    name = params[:name]
    provider_ids = params[:provider_ids]
    
    if name.strip.length > 0  && !provider_ids.blank?
      @team = Team.create(:name => params[:name])
      provider_ids.each do |prov_id|
        @team.providers << prov_id
      end
      @team.user_id = @current_user._id
      @team.save!

      log_controller_call LogAction::ADD, "Create team"
      current_user.teams << @team
      current_user.save!
      redirect_to @team
    else
      log_controller_call LogAction::ADD, "Unable to create team with parameters"
      redirect_to :action => :new
    end
  end
  
  def create_default
    if current_user.practice
      log_controller_call LogAction::ADD, "Create default team"
      @team = Team.find_or_create_by(:name => "All Providers", user_id: current_user.id)
      @team.providers = []
      Provider.where(parent_id: current_user.practice.provider_id).each do |prov|
        @team.providers << prov.id.to_s
      end
      unless current_user.teams.include?(@team)
        current_user.teams << @team
        current_user.save!
      end
    else
      log_page_view "Unable to create default team, user practice is not set. #{params.inspect}"
    end
    redirect_to :action => :index
  end

  # post /teams/1
  def update
    name = params[:name]
    provider_ids = params[:provider_ids]

    if name.strip.length > 0  && !provider_ids.blank?
      @team.name = name
      @team.providers.clear
      provider_ids.each do |prov_id|
        @team.providers << prov_id
      end
      @team.save!
      log_controller_call LogAction::UPDATE, "Updated team"
    else
      log_controller_call LogAction::UPDATE, "Unable to update team with parameters"
    end
    
    redirect_to @team
  end

  # GET /teams/1/edit
  def edit
    log_controller_call LogAction::VIEW, "View page to edit team"
    if current_user.admin? || APP_CONFIG['use_opml_structure']
      @providers = Provider.all
    else
      @providers = Provider.where(parent_id: current_user.practice.provider_id)
    end      
  end

  # DELETE /teams/1
  def destroy
    @current_user.teams.delete(@team)
    @current_user.save!
    
    @team.destroy
    log_controller_call LogAction::DELETE, "Deleted team"
    redirect_to teams_url, notice: 'Team was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_team
      @team = Team.find(params[:id])
      validate_authorization!([@team])
    end
   
    def validate_authorization!(teams)
      teams.each do |team|
        authorize! :manage, team
      end
    end
end
