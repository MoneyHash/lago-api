# frozen_string_literal: true

module PaymentRequests
  module Payments
    class MoneyhashService < BaseService
      include Customers::PaymentProviderFinder

      PENDING_STATUSES = %w[PENDING].freeze
      SUCCESS_STATUSES = %w[PROCESSED].freeze
      FAILED_STATUSES = %w[FAILED].freeze

      def initialize(payable = nil)
        @payable = payable

        super(nil)
      end

      def create
        result.payable = payable
        result.single_validation_failure!(error_code: "payment_method_error") if moneyhash_payment_method.nil?
        return result unless should_process_payment?

        unless payable.total_amount_cents.positive?
          update_payable_payment_status(payment_status: :succeeded)
          return result
        end

        payable.increment_payment_attempts!

        moneyhash_result = create_moneyhash_payment
        return result unless moneyhash_result

        payment = Payment.new(
          payable: payable,
          payment_provider_id: moneyhash_payment_provider.id,
          payment_provider_customer_id: customer.moneyhash_customer.id,
          amount_cents: payable.amount_cents,
          amount_currency: payable.currency&.upcase,
          provider_payment_id: moneyhash_result.dig("data", "id"),
          status: moneyhash_result.dig("data", "status")
        )

        payment.save!

        payable_payment_status = payable_payment_status(payment.status)

        update_payable_payment_status(
          payment_status: payable_payment_status,
          processing: payment.status == "processing"
        )
        update_invoices_payment_status(
          payment_status: payable_payment_status,
          processing: payment.status == "processing"
        )
        result.payment = payment
        result.payable_payment_status
        result
      end

      def update_payment_status(organization_id:, provider_payment_id:, status:, metadata: {})
        payment_obj = Payment.find_or_initialize_by(provider_payment_id: provider_payment_id)
        payment = if payment_obj.persisted?
          payment_obj
        else
          create_payment(provider_payment_id:, metadata:)
        end

        return handle_missing_payment(organization_id, metadata) unless payment

        result.payment = payment
        result.payable = payment.payable
        return result if payment.payable.payment_succeeded?
        payment.update!(status:)

        processing = status == "processing"
        payment_status = payable_payment_status(status)
        update_payable_payment_status(payment_status:, processing:)
        update_invoices_payment_status(payment_status:, processing:)

        PaymentRequestMailer.with(payment_request: payment.payable).requested.deliver_later if result.payable.payment_failed?
        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      private

      attr_accessor :payable

      delegate :organization, :customer, to: :payable

      def handle_missing_payment(organization_id, metadata)
        return result unless metadata&.key?("lago_payable_id")
        payment_request = PaymentRequest.find_by(id: metadata["lago_payable_id"], organization_id:)
        return result unless payment_request
        return result if payment_request.payment_failed?

        result.not_found_failure!(resource: "moneyhash_payment")
      end

      def create_payment(provider_payment_id:, metadata:)
        @payable = PaymentRequest.find_by(id: metadata["lago_payable_id"])

        unless payable
          result.not_found_failure!(resource: "payment_request")
          return
        end

        payable.increment_payment_attempts!

        Payment.new(
          payable:,
          payment_provider_id: moneyhash_payment_provider.id,
          payment_provider_customer_id: customer.moneyhash_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency&.upcase,
          provider_payment_id:
        )
      end

      def moneyhash_payment_method
        customer.moneyhash_customer.payment_method_id
      end

      def should_process_payment?
        return false if payable.payment_succeeded?
        return false if moneyhash_payment_provider.blank?

        !!customer&.moneyhash_customer&.provider_customer_id
      end

      def client
        @client || LagoHttpClient::Client.new("#{::PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/")
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'x-Api-Key' => moneyhash_payment_provider.api_key
        }
      end

      def moneyhash_payment_provider
        @moneyhash_payment_provider ||= payment_provider(customer)
      end

      def create_moneyhash_payment
        payment_params = {
          amount: payable.total_amount_cents / 100.0,
          amount_currency: payable.currency.upcase,
          flow_id: moneyhash_payment_provider.flow_id,
          customer: customer.moneyhash_customer.provider_customer_id,
          webhook_url: moneyhash_payment_provider.webhook_end_point,
          merchant_initiated: true,
          payment_type: "UNSCHEDULED",
          card_token: moneyhash_payment_method,
          recurring_data: {
            agreement_id: payable&.invoices&.first&.subscriptions&.first&.external_id
          },
          custom_fields: {
            lago_mit: true,
            lago_customer_id: customer&.id,
            lago_payable_id: payable.id,
            lago_payable_type: payable.class.name,
            lago_organization_id: organization&.id,
            lago_plan_id: payable&.invoices&.first&.subscriptions&.first&.plan_id,
            lago_subscription_external_id: payable&.invoices&.first&.subscriptions&.first&.external_id,
            lago_mh_service: "PaymentRequests::Payments::MoneyhashService"
          }
        }
        response = client.post_with_response(payment_params, headers)
        JSON.parse(response.body)
      rescue LagoHttpClient::HttpError => e
        deliver_error_webhook(e)
        update_payable_payment_status(payment_status: :failed, deliver_webhook: false)
        nil
      end

      def payable_payment_status(payment_status)
        return :pending if PENDING_STATUSES.include?(payment_status)
        return :succeeded if SUCCESS_STATUSES.include?(payment_status)
        return :failed if FAILED_STATUSES.include?(payment_status)

        payment_status
      end

      def update_payable_payment_status(payment_status:, deliver_webhook: true, processing: false)
        UpdateService.call(
          payable: result.payable,
          params: {
            payment_status:,
            ready_for_payment_processing: !processing && payment_status.to_sym != :succeeded
          },
          webhook_notification: deliver_webhook
        ).raise_if_error!
      end

      def update_invoices_payment_status(payment_status:, deliver_webhook: true, processing: false)
        result.payable.invoices.each do |invoice|
          Invoices::UpdateService.call(
            invoice: invoice,
            params: {
              payment_status:,
              ready_for_payment_processing: !processing && payment_status.to_sym != :succeeded
            },
            webhook_notification: deliver_webhook
          ).raise_if_error!
        end
      end

      def deliver_error_webhook(moneyhash_error)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: customer.moneyhash_customer.provider_customer_id,
          provider_error: {
            message: moneyhash_error.message,
            error_code: moneyhash_error.error_code
          }
        })
      end
    end
  end
end
