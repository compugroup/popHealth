module HealthDataStandards
  module SVS
    class ValueSet
      include Mongoid::Document
      field :categories, type: String
    end
  end
end