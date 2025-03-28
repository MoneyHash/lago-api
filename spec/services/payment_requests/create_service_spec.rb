# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::CreateService, type: :service do
  subject(:create_service) { described_class.new(organization:, params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  let(:first_invoice) do
    create(:invoice, customer:, payment_overdue: true, total_amount_cents: 200, total_paid_amount_cents: 100)
  end

  let(:second_invoice) do
    create(:invoice, customer:, payment_overdue: true, total_amount_cents: 500, total_paid_amount_cents: 200)
  end

  let(:params) do
    {
      external_customer_id: customer.external_id,
      email: "john.doe@example.com",
      lago_invoice_ids: [first_invoice.id, second_invoice.id]
    }
  end

  around { |test| lago_premium!(&test) }

  describe "#call" do
    let(:amount_cents) do
      first_invoice.total_amount_cents + second_invoice.total_amount_cents -
        first_invoice.total_paid_amount_cents - second_invoice.total_paid_amount_cents
    end

    context "when organization is not premium" do
      before do
        allow(License).to receive(:premium?).and_return(false)
      end

      it "returns forbidden failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "when customer does not exist" do
      before { params[:external_customer_id] = "non-existing-id" }

      it "returns not found failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("customer")
      end
    end

    context "when invoices are not found" do
      before { params[:lago_invoice_ids] = [] }

      it "returns not found failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("invoice")
      end
    end

    context "when invoices are not overdue" do
      before { first_invoice.update!(payment_overdue: false) }

      it "returns not allowed failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoices_not_overdue")
      end
    end

    context "when invoices have different currencies" do
      before { second_invoice.update!(currency: "USD") }

      it "returns not allowed failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoices_have_different_currencies")
      end
    end

    context "when invoices are not ready for payment processing" do
      before { first_invoice.update!(ready_for_payment_processing: false) }

      it "returns not allowed failure" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("invoices_not_ready_for_payment_processing")
      end
    end

    it "creates a payment request" do
      expect { create_service.call }.to change { customer.payment_requests.count }.by(1)
    end

    it "assigns the invoices to the created payment request" do
      result = create_service.call

      expect(result.payment_request.invoices.count).to eq(2)
    end

    it "delivers a webhook" do
      create_service.call
      expect(SendWebhookJob).to have_been_enqueued.with("payment_request.created", PaymentRequest)
    end

    it "creates a payment for the payment request" do
      allow(PaymentRequests::Payments::CreateService).to receive(:call_async).and_call_original

      result = create_service.call

      expect(PaymentRequests::Payments::CreateService).to have_received(:call_async).with(payable: result.payment_request)
    end

    context "when Payments::CreateService returns an error" do
      before { customer.update!(payment_provider: nil) }

      it "sends an email to the customer" do
        expect do
          create_service.call
        end.to have_enqueued_job(SendEmailJob)
      end
    end

    it "returns the payment request" do
      dunning_campaign = create(:dunning_campaign, organization:)
      result = described_class.call(organization:, params:, dunning_campaign:)

      expect(result.payment_request).to be_a(PaymentRequest)
      expect(result.payment_request).to have_attributes(
        organization:,
        customer:,
        dunning_campaign:,
        amount_cents:,
        amount_currency: "EUR",
        email: "john.doe@example.com"
      )
    end
  end
end
