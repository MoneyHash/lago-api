# frozen_string_literal: true

module PaymentProviders
  module Moneyhash
    class HandleIncomingWebhookService < BaseService
      def initialize(organization_id:, source:, code:, payload:, signature:, event_type:)
        @organization_id = organization_id
        @source = source
        @code = code
        @payload = payload
        @signature = signature
        @event_type = event_type
        super
      end

      def call
        organization = Organization.find_by(id: organization_id)
        return result.service_failure!(code: "webhook_error", message: "Organization not found") unless organization

        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "moneyhash"
        )

        return handle_payment_provider_failure(payment_provider_result) unless payment_provider_result.success?

        PaymentProviders::Moneyhash::HandleEventJob.perform_later(organization:, event_json: payload)
        result.event = payload
        result
      end

      private

      attr_reader :organization_id, :source, :code, :payload, :signature, :event_type

      def handle_payment_provider_failure(payment_provider_result)
        return payment_provider_result unless payment_provider_result.error.is_a?(BaseService::ServiceFailure)
        result.service_failure!(code: "webhook_error", message: payment_provider_result.error.error_message)
      end
    end
  end
end
