# frozen_string_literal: true

module Types
  module PaymentProviders
    class MoneyhashInput < BaseInputObject
      description 'Moneyhash input arguments'

      argument :api_key, String, required: true
      argument :code, String, required: true
      argument :name, String, required: true
      argument :flow_id, String, required: false
      argument :redirect_url, String, required: false
    end
  end
end
