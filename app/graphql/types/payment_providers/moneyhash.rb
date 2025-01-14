# frozen_string_literal: true

module Types
  module PaymentProviders
    class Moneyhash < Types::BaseObject
      graphql_name 'MoneyhashProvider'

      field :code, String, null: false
      field :id, ID, null: false
      field :name, String, null: false
      field :api_key, String, null: true, permission: 'organization:integrations:view'
      field :success_redirect_url, String, null: true, permission: 'organization:integrations:view'
      field :failed_redirect_url, String, null: true, permission: 'organization:integrations:view'
      field :pending_redirect_url, String, null: false, permission: 'organization:integrations:view'
      field :webhook_redirect_url, String, null: true, permission: 'organization:integrations:view'

      # NOTE: Api key is a sensitive information. It should not be sent back to the
      #       front end application. Instead we send an obfuscated value
      def api_key
        "#{"•" * 8}…#{object.api_key[-3..]}"
      end
    end
  end
end
