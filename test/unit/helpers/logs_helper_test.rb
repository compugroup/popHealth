require 'test_helper'

def current_user
  nil
end

class LogsHelperTest < ActionView::TestCase
  setup do
    dump_database
    collection_fixtures 'users', 'records'
    @current_user = User.where({email: 'admin@test.com'}).first
    @logging_config = APP_CONFIG['log_to_database']
  end

  teardown do
    @current_user = User.where({email: 'admin@test.com'}).first
    APP_CONFIG['log_to_database'] = @logging_config
  end

  test "should be able to add the time to the rest of the params" do
    existing_params = {:page => 4}
    params[:log_start_date] = 'tomorrow'
    time_range_params_plus(existing_params)
    assert_equal 4, existing_params[:page]
    assert_equal 'tomorrow', existing_params[:log_start_date]
  end
  
  test "should log controller" do
    assert_difference('Log.count') do
      log_controller_call LogAction::ADD, "Controller Test"
    end
    log = Log.last
    assert_equal "Controller - Controller Test Parameters: {}", log.description
  end

  test "should log API" do
    assert_difference('Log.count') do
      log_api_call LogAction::ADD, "API Test"
    end
    log = Log.last
    assert_equal "API - API Test Parameters: {}", log.description
  end

  test "should log admin API" do
    assert_difference('Log.count') do
      log_admin_api_call LogAction::ADD, "Admin API Test"
    end
    log = Log.last
    assert_equal "Admin API - Admin API Test Parameters: {}", log.description
  end

  test "should log admin controller" do
    assert_difference('Log.count') do
      log_admin_controller_call LogAction::ADD, "Admin Controller Test"
    end
    log = Log.last
    assert_equal "Admin Controller - Admin Controller Test Parameters: {}", log.description
  end

  test "should not write a log if there is no log config" do
    APP_CONFIG['log_to_database'] = nil
    assert_no_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, true, true, true
    end
  end

  test "should log MRN when patient is available" do
    @patient = Record.first
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, true, true, true
    end
    log = Log.last
    assert_equal @patient.medical_record_number, log.medical_record_number
  end

  test "should log parameters when available" do
    def params
      # Note that controller should be filtered out
      { :controller => "test", :id => "23" }
    end

    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, true, true, true
    end
    log = Log.last
    assert_equal "Test details Parameters: {:id=>\"23\"}", log.description
  end

  test "should log affected username when it is available" do
    @user = User.last
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, true, true, true
    end
    log = Log.last
    assert_equal @user.username, log.affected_user
  end

  # This block handles when logging should take place, based on the configuration
  # parameters.
  test "should write a log if controller logging is enabled" do
    APP_CONFIG['log_to_database']['controller'] = true
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, false, false, false
    end
  end

  test "should not write a log if controller logging is disabled" do
    APP_CONFIG['log_to_database']['controller'] = false
    assert_no_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", true, false, false, false
    end
  end

  test "should write a log if admin logging is enabled" do
    APP_CONFIG['log_to_database']['admin'] = true
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, true, false, false
    end
  end

  test "should not write a log if admin logging is disabled" do
    APP_CONFIG['log_to_database']['admin'] = false
    assert_no_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, true, false, false
    end
  end

  test "should write a log if API logging is enabled" do
    APP_CONFIG['log_to_database']['api'] = true
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, false, true, false
    end
  end

  test "should not write a log if API logging is disabled" do
    APP_CONFIG['log_to_database']['api'] = false
    assert_no_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, false, true, false
    end
  end

  test "should write a log if sensitive logging is enabled" do
    APP_CONFIG['log_to_database']['is_sensitive'] = true
    assert_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, false, false, true
    end
  end

  test "should not write a log if sensitive logging is disabled" do
    APP_CONFIG['log_to_database']['is_sensitive'] = false
    assert_no_difference('Log.count') do
      log_call LogAction::ADD, "Test", "Test details", false, false, false, true
    end
  end
end

