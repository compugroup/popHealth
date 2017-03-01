class CustomFailure < Devise::FailureApp
  # We override respond to eliminate recall, which causes errors
  def respond
    if http_auth?
      http_auth
    else
      redirect
    end
  end
end