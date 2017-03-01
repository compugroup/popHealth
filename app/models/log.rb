class Log
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :username, :type => String
  field :action, :type => String
  field :event, :type => String
  field :description, :type => String
  field :medical_record_number, :type => String
  field :affected_user, :type => String
  field :checksum, :type => String
  
end