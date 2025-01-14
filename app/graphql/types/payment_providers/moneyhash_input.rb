# frozen_string_literal: true

module Types
  module PaymentProviders
    class MoneyhashInput < BaseInputObject
      description 'Moneyhash input arguments'

      argument :api_key, String, required: true
      argument :code, String, required: true
      argument :name, String, required: true
      argument :success_redirect_url, String, required: false
      argument :failed_redirect_url, String, required: false
      argument :pending_redirect_url, String, required: true
      argument :webhook_redirect_url, String, required: true
    end
  end
end
